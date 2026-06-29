// ════════════════════════════════════════════════════════════════════════════
// 기록 리마인더 크론 — 오늘 영수증을 아직 등록 안 한 옵트인 유저에게 Web Push (b583)
//
//   POST /api/cron/log-reminder
//   Header: Authorization: Bearer <CRON_SECRET>
//
//   알고리즘:
//   1. logreminder_optin=true 활성 구독 조회
//   2. 오늘(JST) receipt_date 인 영수증을 가진 유저 집합 조회
//   3. 옵트인 유저 중 "오늘 기록 없는" 유저에게만 push
//   4. 410/404 만료 구독 자동 삭제
//
//   호출: GitHub Actions cron 1일 1회 (log-reminder.yml, JST 20:00)
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
    .eq('logreminder_optin', true);
  if (subsErr) return Response.json({ ok: false, err: 'subs: ' + subsErr.message }, { status: 500 });
  if (!subs || subs.length === 0) return Response.json({ ok: true, sent: 0, note: 'no opt-in subscribers' });

  const subsByUser = new Map<string, any[]>();
  for (const s of subs) {
    if (!subsByUser.has(s.user_id)) subsByUser.set(s.user_id, []);
    subsByUser.get(s.user_id)!.push(s);
  }
  const userIds = Array.from(subsByUser.keys());

  // 2) 오늘(JST) 기록 있는 유저
  const nowJst = new Date(Date.now() + 9 * 3600 * 1000);
  const todayJst = nowJst.toISOString().slice(0, 10); // YYYY-MM-DD (JST)
  const { data: todays, error: rcErr } = await sb
    .from('receipts')
    .select('user_id')
    .eq('receipt_date', todayJst)
    .in('user_id', userIds);
  if (rcErr) return Response.json({ ok: false, err: 'receipts: ' + rcErr.message }, { status: 500 });
  const logged = new Set<string>();
  for (const r of (todays || [])) logged.add(r.user_id);

  // 3) 오늘 기록 없는 옵트인 유저에게만 push
  const targets = userIds.filter((u) => !logged.has(u));
  if (targets.length === 0) return Response.json({ ok: true, sent: 0, note: 'all opt-in users already logged today' });

  const payload = JSON.stringify({
    title: '📝 今日の家計簿',
    body: '今日のレシート、まだ登録していません。サッと記録しましょう！',
    url: '/?from=logreminder',
    tag: 'logreminder',
    priority: 'normal',
    icon: '/icons/icon-192.png',
    badge: '/icons/icon-192.png'
  });
  const pushOptions = { TTL: 43200, urgency: 'normal' } as any;

  const expiredIds: string[] = [];
  let sent = 0, failed = 0;

  await Promise.all(targets.map(async (uid) => {
    const userSubs = subsByUser.get(uid) || [];
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
    if (anyOk) sent++; else failed++;
  }));

  if (expiredIds.length > 0) await sb.from('push_subscriptions').delete().in('id', expiredIds);

  return Response.json({ ok: true, targets: targets.length, sent, failed, expired_deleted: expiredIds.length });
}
