// ════════════════════════════════════════════════════════════════════════════
// 가격 변동 알림 크론 — 자주 사는 상품이 내 동네에서 더 싸지면 Web Push  (Phase 1, b531)
//
//   POST /api/cron/price-watch
//   Header: Authorization: Bearer <CRON_SECRET>
//
//   알고리즘 (앱이 꺼져 있어도 서버가 계산 → push):
//   1. pricewatch_optin=true 활성 구독 조회 → 옵트인 유저/디바이스
//   2. 그 유저들의 product_prices(=내가 산 상품·가게·단가·좌표·용량) 한 번에 조회
//      → 유저별 앵커위치(내 구매 좌표 중심) + 상품별 내 단가/가게
//   3. 해당 상품들의 커뮤니티 product_prices 전체 조회
//      → 앵커 반경 R 내 더 싼 가게(용량 단가 비교) 탐색
//   4. 임계(≥10% 단가↓) 넘으면 유저당 "가장 큰 절약" 1건 선정
//   5. price_alerts_sent 7일 쿨다운으로 도배 방지 → Web Push 발송
//   6. 410/404 만료 구독 자동 삭제
//
//   호출: GitHub Actions cron 1일 1회 (price-watch.yml)
// ════════════════════════════════════════════════════════════════════════════

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

import { createClient } from '@supabase/supabase-js';
import * as webpush from 'web-push';

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL || '';
const SUPABASE_SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
const VAPID_PUBLIC  = process.env.VAPID_PUBLIC_KEY  || '';
const VAPID_PRIVATE = process.env.VAPID_PRIVATE_KEY || '';
const VAPID_SUBJECT = process.env.VAPID_SUBJECT     || 'mailto:admin@retwork.jp';
const CRON_SECRET   = process.env.CRON_SECRET       || '';

if (VAPID_PUBLIC && VAPID_PRIVATE) {
  webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC, VAPID_PRIVATE);
}

// ── 튜닝 파라미터 (조정 가능) ──
const RADIUS_M      = 3000;   // 앵커 반경 (m)
const MIN_PCT       = 10;     // 최소 절약율 (%) — 단가 기준
const COOLDOWN_DAYS = 7;      // 같은 (유저·상품·가게) 알림 쿨다운

function haversineM(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371000, toRad = (d: number) => d * Math.PI / 180;
  const dLat = toRad(lat2 - lat1), dLng = toRad(lng2 - lng1);
  const a = Math.sin(dLat/2)**2 + Math.cos(toRad(lat1))*Math.cos(toRad(lat2))*Math.sin(dLng/2)**2;
  return 2 * R * Math.asin(Math.sqrt(a));
}
// 용량 단가 비교: 둘 다 qty_base+같은 kind 면 ¥/base, 아니면 raw 단가
function unitPair(mine: any, cand: any): { mu: number; cu: number } {
  if (mine.qty_base > 0 && cand.qty_base > 0 && mine.qty_kind && mine.qty_kind === cand.qty_kind) {
    return { mu: mine.price / mine.qty_base, cu: cand.price / cand.qty_base };
  }
  return { mu: mine.price, cu: cand.price };
}
function fmtDist(m: number): string {
  return m >= 1000 ? (Math.round(m / 100) / 10) + 'km' : Math.round(m) + 'm';
}

export async function POST(request: Request) {
  const auth = request.headers.get('authorization') || '';
  const token = auth.replace(/^Bearer\s+/i, '').trim();
  if (!CRON_SECRET || token !== CRON_SECRET) {
    return Response.json({ ok: false, err: 'unauthorized' }, { status: 401 });
  }
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE || !VAPID_PUBLIC || !VAPID_PRIVATE) {
    return Response.json({ ok: false, err: 'server env not configured' }, { status: 500 });
  }

  const sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE, {
    auth: { persistSession: false, autoRefreshToken: false }
  });

  // 1) 옵트인 활성 구독
  const { data: subs, error: subsErr } = await sb
    .from('push_subscriptions')
    .select('id, user_id, endpoint, p256dh, auth')
    .eq('enabled', true)
    .eq('pricewatch_optin', true);
  if (subsErr) return Response.json({ ok: false, err: 'subs: ' + subsErr.message }, { status: 500 });
  if (!subs || subs.length === 0) return Response.json({ ok: true, sent: 0, note: 'no opt-in subscribers' });

  const subsByUser = new Map<string, any[]>();
  for (const s of subs) {
    if (!subsByUser.has(s.user_id)) subsByUser.set(s.user_id, []);
    subsByUser.get(s.user_id)!.push(s);
  }
  const userIds = Array.from(subsByUser.keys());

  // 2) 옵트인 유저들의 "내가 산 것"
  const { data: myAll, error: myErr } = await sb
    .from('product_prices')
    .select('user_id, product_id, store_name, price, lat, lng, qty_base, qty_kind')
    .in('user_id', userIds);
  if (myErr) return Response.json({ ok: false, err: 'my: ' + myErr.message }, { status: 500 });

  // 유저별 그룹 + 앵커 + 상품별 내 최저단가
  type Mine = { product_id: string; store_name: string; price: number; qty_base: number; qty_kind: string };
  const byUser = new Map<string, { anchor: { lat: number; lng: number } | null; byPid: Map<string, Mine> }>();
  const pidSet = new Set<string>();
  for (const uid of userIds) byUser.set(uid, { anchor: null, byPid: new Map() });
  const accLat = new Map<string, { sum: number; cnt: number }>();
  const accLng = new Map<string, { sum: number; cnt: number }>();
  for (const r of (myAll || [])) {
    const u = byUser.get(r.user_id); if (!u) continue;
    if (r.lat != null && r.lng != null) {
      if (!accLat.has(r.user_id)) { accLat.set(r.user_id, { sum: 0, cnt: 0 }); accLng.set(r.user_id, { sum: 0, cnt: 0 }); }
      accLat.get(r.user_id)!.sum += r.lat; accLat.get(r.user_id)!.cnt++;
      accLng.get(r.user_id)!.sum += r.lng; accLng.get(r.user_id)!.cnt++;
    }
    // 상품별 내 최저 raw 단가 보존 (대표 1행)
    const cur = u.byPid.get(r.product_id);
    if (!cur || r.price < cur.price) {
      u.byPid.set(r.product_id, { product_id: r.product_id, store_name: r.store_name, price: r.price, qty_base: r.qty_base || 0, qty_kind: r.qty_kind || '' });
    }
    pidSet.add(r.product_id);
  }
  for (const uid of userIds) {
    const a = accLat.get(uid);
    if (a && a.cnt > 0) byUser.get(uid)!.anchor = { lat: a.sum / a.cnt, lng: accLng.get(uid)!.sum / accLng.get(uid)!.cnt };
  }

  const pids = Array.from(pidSet);
  if (pids.length === 0) return Response.json({ ok: true, sent: 0, note: 'no product prices for opt-in users' });

  // 3) 그 상품들의 커뮤니티 가격
  const { data: comm, error: commErr } = await sb
    .from('product_prices')
    .select('product_id, store_name, price, lat, lng, qty_base, qty_kind')
    .in('product_id', pids);
  if (commErr) return Response.json({ ok: false, err: 'comm: ' + commErr.message }, { status: 500 });
  const commByPid = new Map<string, any[]>();
  for (const r of (comm || [])) {
    if (!commByPid.has(r.product_id)) commByPid.set(r.product_id, []);
    commByPid.get(r.product_id)!.push(r);
  }

  // 4) 유저별 최적 알림 선정
  type Alert = { user_id: string; product_id: string; store: string; candPrice: number; myStore: string; myPrice: number; pct: number; distM: number };
  const alerts: Alert[] = [];
  for (const uid of userIds) {
    const u = byUser.get(uid)!;
    if (!u.anchor) continue;
    let best: Alert | null = null;
    for (const [pid, mine] of u.byPid) {
      const cands = commByPid.get(pid) || [];
      for (const c of cands) {
        if (c.store_name === mine.store_name) continue;       // 같은 가게 제외
        if (c.lat == null || c.lng == null) continue;
        const dist = haversineM(u.anchor.lat, u.anchor.lng, c.lat, c.lng);
        if (dist > RADIUS_M) continue;
        const { mu, cu } = unitPair(mine, c);
        if (!(mu > 0) || !(cu > 0)) continue;
        const pct = Math.round((mu - cu) / mu * 100);
        if (pct < MIN_PCT) continue;
        if (!best || pct > best.pct) {
          best = { user_id: uid, product_id: pid, store: c.store_name, candPrice: c.price, myStore: mine.store_name, myPrice: mine.price, pct, distM: Math.round(dist) };
        }
      }
    }
    if (best) alerts.push(best);
  }
  if (alerts.length === 0) return Response.json({ ok: true, sent: 0, note: 'no cheaper-nearby found' });

  // 5) 쿨다운 dedup
  const cutoff = new Date(Date.now() - COOLDOWN_DAYS * 86400000).toISOString();
  const { data: sentRows } = await sb
    .from('price_alerts_sent')
    .select('user_id, product_id, store_name, sent_at')
    .in('user_id', userIds)
    .gte('sent_at', cutoff);
  const sentKey = new Set((sentRows || []).map((r: any) => r.user_id + '|' + r.product_id + '|' + r.store_name));
  const fresh = alerts.filter(a => !sentKey.has(a.user_id + '|' + a.product_id + '|' + a.store));
  if (fresh.length === 0) return Response.json({ ok: true, sent: 0, note: 'all on cooldown' });

  // 상품명 (products_master.canonical)
  const namePids = Array.from(new Set(fresh.map(a => a.product_id)));
  const { data: names } = await sb.from('products_master').select('id, canonical').in('id', namePids);
  const nameById = new Map<string, string>();
  for (const n of (names || [])) nameById.set(n.id, n.canonical || '商品');

  // 6) 발송 (유저당 1건 → 유저의 모든 디바이스로)
  const pushOptions = { TTL: 86400, urgency: 'normal' } as any;
  const expiredIds: string[] = [];
  let sent = 0, failed = 0;

  await Promise.all(fresh.map(async (a) => {
    const name = nameById.get(a.product_id) || '商品';
    const diff = a.myPrice - a.candPrice;
    const diffTxt = diff > 0 ? `（¥${a.candPrice} / あなた¥${a.myPrice}）` : `（約${a.pct}%お得）`;
    const payload = JSON.stringify({
      title: '💰 もっと安いお店が見つかりました',
      body: `${name} — ${a.store} が「${a.myStore}」より約${a.pct}%安い ${diffTxt}｜${fmtDist(a.distM)}`,
      url: '/',
      tag: 'pricewatch-' + a.product_id,   // 같은 상품 알림 그룹화
      priority: 'normal',
      icon: '/icons/icon-192.png',
      badge: '/icons/icon-192.png'
    });
    const userSubs = subsByUser.get(a.user_id) || [];
    let anyOk = false;
    await Promise.all(userSubs.map(async (s) => {
      try {
        await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } } as any, payload, pushOptions);
        anyOk = true;
        sb.from('push_subscriptions').update({ last_sent_at: new Date().toISOString(), last_error: null }).eq('id', s.id).then(() => {});
      } catch (e: any) {
        const sc = e?.statusCode;
        if (sc === 404 || sc === 410) expiredIds.push(s.id);
        else sb.from('push_subscriptions').update({ last_error: (e?.message || 'unknown').substring(0, 200) }).eq('id', s.id).then(() => {});
      }
    }));
    if (anyOk) {
      sent++;
      // 쿨다운 기록 (upsert: 같은 유저·상품·가게면 sent_at 갱신)
      await sb.from('price_alerts_sent').upsert(
        { user_id: a.user_id, product_id: a.product_id, store_name: a.store, price: a.candPrice, sent_at: new Date().toISOString() },
        { onConflict: 'user_id,product_id,store_name' }
      );
    } else {
      failed++;
    }
  }));

  if (expiredIds.length > 0) await sb.from('push_subscriptions').delete().in('id', expiredIds);

  return Response.json({ ok: true, candidates: alerts.length, fresh: fresh.length, sent, failed, expired_deleted: expiredIds.length });
}
