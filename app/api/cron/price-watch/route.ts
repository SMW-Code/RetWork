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
const RADIUS_M            = 3000;  // 앵커 반경 (m)
const MIN_PCT             = 10;    // 최소 절약율 (%) — 단가 기준
// 적응형 푸시 빈도 캡 (참여=관심 / 무시=백오프). 딜 "기록(인앱)"은 캡과 무관하게 항상.
const ENGAGED_WINDOW_DAYS = 14;    // 최근 N일 내 푸시 탭 → '관심' → 캡 3일
const CAP_ENGAGED         = 3;     // 관심/신규/중립 기본 캡(일)
const CAP_IGNORE_MID      = 7;     // 무시 누적(streak 3~5) → 7일
const CAP_IGNORE_HIGH     = 14;    // 무시 누적(streak 6+) → 14일

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
    // 임시 진단(비밀값 미노출 — 설정여부·길이만). 해결 후 제거.
    return Response.json({ ok: false, err: 'unauthorized', _dbg: {
      cronSet: !!CRON_SECRET, cronLen: (CRON_SECRET || '').length, tokenLen: token.length, match: token === CRON_SECRET,
      vapidSet: !!(VAPID_PUBLIC && VAPID_PRIVATE), supaUrlSet: !!SUPABASE_URL, supaRoleSet: !!SUPABASE_SERVICE_ROLE
    } }, { status: 401 });
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

  // 5) 적응형 푸시 상태 + 상품명
  const { data: stRows } = await sb
    .from('pricewatch_state')
    .select('user_id, last_pushed_at, last_engaged_at, ignored_streak')
    .in('user_id', userIds);
  const stateByUser = new Map<string, any>();
  for (const r of (stRows || [])) stateByUser.set(r.user_id, r);

  const namePids = Array.from(new Set(alerts.map(a => a.product_id)));
  const { data: names } = await sb.from('products_master').select('id, canonical').in('id', namePids);
  const nameById = new Map<string, string>();
  for (const n of (names || [])) nameById.set(n.id, n.canonical || '商品');

  const DAY = 86400000, now = Date.now();
  // 적응형 캡(일): 최근 14일 내 푸시 탭 = 관심 → 3일. 무시 누적 → 점진 백오프.
  function capDaysFor(st: any): number {
    if (st && st.last_engaged_at && (now - new Date(st.last_engaged_at).getTime()) <= ENGAGED_WINDOW_DAYS * DAY) return CAP_ENGAGED;
    const s = (st && st.ignored_streak) || 0;
    if (s >= 6) return CAP_IGNORE_HIGH;
    if (s >= 3) return CAP_IGNORE_MID;
    return CAP_ENGAGED;
  }

  // 6) 딜은 항상 기록(인앱 벨/NEW), 푸시는 적응형 캡 통과시만
  const pushOptions = { TTL: 86400, urgency: 'normal' } as any;
  const expiredIds: string[] = [];
  const stateUpserts: any[] = [];
  let recorded = 0, sent = 0, throttled = 0, failed = 0;

  await Promise.all(alerts.map(async (a) => {
    const name = nameById.get(a.product_id) || '商品';
    const diff = a.myPrice - a.candPrice;
    const diffTxt = diff > 0 ? `（¥${a.candPrice} / あなた¥${a.myPrice}）` : `（約${a.pct}%お得）`;
    const msgBody = `${name} — ${a.store} が「${a.myStore}」より約${a.pct}%安い ${diffTxt}｜${fmtDist(a.distM)}`;

    // (a) 항상 기록 → 인앱 벨/NEW/알림함 (캡과 무관)
    await sb.from('price_alerts_sent').upsert(
      { user_id: a.user_id, product_id: a.product_id, store_name: a.store, price: a.candPrice, body: msgBody, sent_at: new Date().toISOString() },
      { onConflict: 'user_id,product_id,store_name' }
    );
    recorded++;

    // (b) 적응형 캡 — 무시형은 백오프, 관심형은 자주
    const st = stateByUser.get(a.user_id);
    const lastPushed = st && st.last_pushed_at ? new Date(st.last_pushed_at).getTime() : 0;
    const eligible = !lastPushed || (now - lastPushed) >= capDaysFor(st) * DAY;
    if (!eligible) { throttled++; return; }

    // (c) 푸시 (유저의 모든 디바이스). url 플래그로 '탭=engagement' 추적
    const payload = JSON.stringify({
      title: '💰 もっと安いお店が見つかりました',
      body: msgBody,
      url: '/?from=pricewatch',
      tag: 'pricewatch-' + a.product_id,
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
      // 푸시 보냄 → last_pushed_at 갱신 + 무시 streak +1 (탭하면 앱이 0으로 리셋)
      stateUpserts.push({ user_id: a.user_id, last_pushed_at: new Date().toISOString(), ignored_streak: (((st && st.ignored_streak) || 0) + 1), updated_at: new Date().toISOString() });
    } else {
      failed++;
    }
  }));

  // engagement(last_engaged_at)은 앱이 갱신하므로 여기선 미포함 → upsert 시 기존값 보존
  if (stateUpserts.length > 0) await sb.from('pricewatch_state').upsert(stateUpserts, { onConflict: 'user_id' });
  if (expiredIds.length > 0)   await sb.from('push_subscriptions').delete().in('id', expiredIds);

  return Response.json({ ok: true, candidates: alerts.length, recorded, sent, throttled, failed, expired_deleted: expiredIds.length });
}
