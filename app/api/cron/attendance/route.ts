// ════════════════════════════════════════════════════════════════════════════
// 출석 슬롯 시작 알림 — GitHub Actions cron 호출용 (build 317)
//
//   POST /api/cron/attendance
//   Header:  Authorization: Bearer <CRON_SECRET>
//   Body:    { slot: 'morning' | 'afternoon' }  (선택 — 메시지 차별화)
//
//   동작:
//   1. Authorization 검증 (CRON_SECRET 환경변수)
//   2. push_subscriptions 에서 enabled=true AND attendance_optin=true 조회
//   3. 각 구독에 web-push 발송 (병렬, 410 시 만료 자동 삭제)
//   4. 결과 반환: { sent, failed, expired_deleted }
//
//   호출 빈도: 일 2회 (JST 8시, 16시) — GitHub Actions workflow 참고
// ════════════════════════════════════════════════════════════════════════════

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

import { createClient } from '@supabase/supabase-js';
import * as webpush from 'web-push';
import { sendFcmToTokens } from '@/lib/fcm';

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
  // 1. 인증 — CRON_SECRET 검증
  const auth = request.headers.get('authorization') || '';
  const token = auth.replace(/^Bearer\s+/i, '').trim();
  if (!CRON_SECRET || token !== CRON_SECRET) {
    return Response.json({ ok: false, err: 'unauthorized' }, { status: 401 });
  }
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE || !VAPID_PUBLIC || !VAPID_PRIVATE) {
    return Response.json({ ok: false, err: 'server env not configured' }, { status: 500 });
  }

  // 2. body 파싱 (slot 종류 — 메시지 변형용)
  let body: any = {};
  try { body = await request.json(); } catch (e) { body = {}; }
  const slot = (body?.slot || 'morning').toString();
  const slotLabel = slot === 'afternoon' ? '오후 슬롯' : '오전 슬롯';
  const title = '⏰ ' + slotLabel + ' 출석 가능!';
  const msgBody = '지금 출석하고 +5 치리 받기 → 광고 보면 +20 치리';

  const sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE, {
    auth: { persistSession: false, autoRefreshToken: false }
  });

  // 3. 옵트인한 활성 구독 조회
  const { data: subs, error: subsErr } = await sb
    .from('push_subscriptions')
    .select('id, user_id, endpoint, p256dh, auth')
    .eq('enabled', true)
    .eq('attendance_optin', true);

  if (subsErr) {
    return Response.json({ ok: false, err: 'subs fetch failed: ' + subsErr.message }, { status: 500 });
  }

  // 네이티브(FCM) 토큰 — attendance_optin
  const { data: ntoks } = await sb
    .from('native_push_tokens')
    .select('token')
    .eq('enabled', true)
    .eq('attendance_optin', true);
  const nativeTokens = (ntoks || []).map((r: any) => r.token).filter(Boolean);

  if ((!subs || subs.length === 0) && nativeTokens.length === 0) {
    return Response.json({ ok: true, sent: 0, note: 'no opt-in subscribers' });
  }

  // 4. payload
  const payload = JSON.stringify({
    title,
    body: msgBody,
    url: '/',
    tag: 'attendance-' + slot,    // 같은 슬롯은 그룹화 (스팸 방지)
    priority: 'normal',
    icon: '/icons/icon-192.png',
    badge: '/icons/icon-192.png'
  });

  const pushOptions = {
    TTL: 28800,                   // 8시간 (다음 슬롯까지)
    urgency: 'normal'
  } as any;

  // 5. 병렬 발송
  const expiredIds: string[] = [];
  const results = await Promise.allSettled((subs || []).map(async (s) => {
    const subscription = {
      endpoint: s.endpoint,
      keys: { p256dh: s.p256dh, auth: s.auth }
    };
    try {
      await webpush.sendNotification(subscription as any, payload, pushOptions);
      sb.from('push_subscriptions').update({
        last_sent_at: new Date().toISOString(), last_error: null
      }).eq('id', s.id).then(() => {});
      return { ok: true, id: s.id };
    } catch (e: any) {
      const statusCode = e?.statusCode;
      if (statusCode === 404 || statusCode === 410) {
        expiredIds.push(s.id);
      } else {
        sb.from('push_subscriptions').update({
          last_error: (e?.message || 'unknown').substring(0, 200)
        }).eq('id', s.id).then(() => {});
      }
      return { ok: false, id: s.id, err: e?.message, statusCode };
    }
  }));

  if (expiredIds.length > 0) {
    await sb.from('push_subscriptions').delete().in('id', expiredIds);
  }

  const webSent = results.filter(r => r.status === 'fulfilled' && (r.value as any).ok).length;
  const webFailed = results.length - webSent;

  // 네이티브(FCM) 발송 — 옵트인 토큰 전체
  let nativeSent = 0, nativeFailed = 0, nativeDeleted = 0;
  if (nativeTokens.length) {
    const fr = await sendFcmToTokens(nativeTokens, { title, body: msgBody, url: '/', tag: 'attendance-' + slot, priority: 'normal' });
    nativeSent = fr.sent;
    nativeFailed = fr.failed;
    if (fr.invalidTokens.length) {
      await sb.from('native_push_tokens').delete().in('token', fr.invalidTokens);
      nativeDeleted = fr.invalidTokens.length;
    }
  }

  return Response.json({
    ok: true,
    slot,
    total: results.length + nativeSent + nativeFailed,
    sent: webSent + nativeSent,
    failed: webFailed + nativeFailed,
    web: { sent: webSent, failed: webFailed },
    native: { sent: nativeSent, failed: nativeFailed },
    expired_deleted: expiredIds.length,
    native_invalid_deleted: nativeDeleted
  });
}
