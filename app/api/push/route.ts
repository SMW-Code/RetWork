// ════════════════════════════════════════════════════════════════════════════
// 푸시 알림 발송 API (build 306)
//
//   POST /api/push
//   Body: { recipient_ids: string[], title: string, body: string,
//           url?: string, tag?: string, messageId?: string }
//   Header: Authorization: Bearer <user_jwt>  (어드민 검증용)
//
//   1) Bearer 토큰으로 사용자 인증
//   2) profiles.is_admin = true 확인
//   3) push_subscriptions 에서 대상 사용자들의 활성 구독 조회
//   4) web-push 로 각 구독에 발송
//   5) 410 Gone 에러 시 해당 구독 삭제
// ════════════════════════════════════════════════════════════════════════════

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

import { createClient } from '@supabase/supabase-js';
// web-push 는 CommonJS — namespace import 가 가장 호환성 좋음
import * as webpush from 'web-push';
// 네이티브(FCM) 발송 — 웹 web-push 와 별개로 native_push_tokens 로 발송
import { sendFcmToTokens, isFcmConfigured } from '@/lib/fcm';

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL || '';
const SUPABASE_SERVICE_ROLE = process.env.SUPABASE_SERVICE_ROLE_KEY || '';
const VAPID_PUBLIC  = process.env.VAPID_PUBLIC_KEY  || '';
const VAPID_PRIVATE = process.env.VAPID_PRIVATE_KEY || '';
const VAPID_SUBJECT = process.env.VAPID_SUBJECT     || 'mailto:admin@retwork.jp';

if (VAPID_PUBLIC && VAPID_PRIVATE) {
  webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC, VAPID_PRIVATE);
}

export async function POST(request: Request) {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE) {
    return Response.json({ ok: false, err: 'supabase env not configured' }, { status: 500 });
  }
  if (!VAPID_PUBLIC || !VAPID_PRIVATE) {
    return Response.json({ ok: false, err: 'vapid keys not configured' }, { status: 500 });
  }

  // 1) 인증 헤더에서 JWT 추출
  const authHeader = request.headers.get('authorization') || '';
  const jwt = authHeader.replace(/^Bearer\s+/i, '').trim();
  if (!jwt) {
    return Response.json({ ok: false, err: 'unauthorized' }, { status: 401 });
  }

  // service role 클라이언트 (RLS 우회)
  const sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE, {
    auth: { persistSession: false, autoRefreshToken: false }
  });

  // 2) JWT 로 사용자 확인
  const { data: userData, error: userErr } = await sb.auth.getUser(jwt);
  if (userErr || !userData || !userData.user) {
    return Response.json({ ok: false, err: 'invalid token' }, { status: 401 });
  }
  const senderId = userData.user.id;

  // 3) 권한 검증 — type 따라 분기 (build 314)
  //    - admin (기본): 어드민만 발송 가능
  //    - social: 일반 사용자도 발송 가능 (다른 사용자에게만, 본인에게는 금지)
  //    - broadcast: 어드민만
  // 어드민 여부 조회 (실제 권한 분기는 본문 파싱 후 reqKind 따라)
  const { data: prof } = await sb
    .from('profiles')
    .select('is_admin')
    .eq('id', senderId)
    .maybeSingle();
  const isAdmin = !!(prof && prof.is_admin);

  // 4) 본문 파싱
  let body: any;
  try {
    body = await request.json();
  } catch (e) {
    return Response.json({ ok: false, err: 'invalid json' }, { status: 400 });
  }
  const recipientIds: string[] = Array.isArray(body?.recipient_ids) ? body.recipient_ids : [];
  const title = (body?.title || '').toString().trim();
  const msgBody = (body?.body || '').toString().trim();
  const url = (body?.url || '/').toString();
  const tag = (body?.tag || 'retwork-msg').toString();
  const messageId = body?.messageId || null;
  const broadcast = body?.broadcast === true;  // true = 전체 발송
  const priority = (body?.priority || 'normal').toString();  // build 310 — 헤즈업 강화용
  const reqKind  = (body?.type || 'admin').toString();        // build 314 — admin | social

  // build 314 — 권한 분기
  //   broadcast → 어드민만
  //   admin     → 어드민만
  //   social    → 누구든 (단 본인에게 발송 금지)
  if (broadcast && !isAdmin) {
    return Response.json({ ok: false, err: 'broadcast forbidden (admin only)' }, { status: 403 });
  }
  if (reqKind === 'admin' && !isAdmin) {
    return Response.json({ ok: false, err: 'forbidden (admin only)' }, { status: 403 });
  }
  if (reqKind === 'social') {
    // 본인에게 알림 금지 (셀프 push 어뷰져 방지)
    if (recipientIds.includes(senderId)) {
      return Response.json({ ok: false, err: 'cannot send social to self' }, { status: 400 });
    }
    // social 은 최대 1명만 (좋아요/댓글 같은 1:1 알림)
    if (recipientIds.length > 1) {
      return Response.json({ ok: false, err: 'social must be 1 recipient' }, { status: 400 });
    }
  }

  if (!title || !msgBody) {
    return Response.json({ ok: false, err: 'title and body required' }, { status: 400 });
  }
  if (!broadcast && recipientIds.length === 0) {
    return Response.json({ ok: false, err: 'no recipients (or pass broadcast=true)' }, { status: 400 });
  }

  // 5) 구독 조회
  let subsQuery = sb.from('push_subscriptions')
    .select('id, user_id, endpoint, p256dh, auth')
    .eq('enabled', true);
  if (!broadcast) {
    subsQuery = subsQuery.in('user_id', recipientIds);
  }
  const { data: subs, error: subsErr } = await subsQuery;
  if (subsErr) {
    return Response.json({ ok: false, err: 'subs fetch failed: ' + subsErr.message }, { status: 500 });
  }
  // 웹 구독이 0개여도 네이티브(FCM) 발송은 계속 진행 (조기 반환 X)
  const webSubs = subs || [];

  // 6) 각 구독에 발송 (병렬)
  const payload = JSON.stringify({
    title, body: msgBody, url, tag, messageId, priority,
    icon: '/icons/icon.png',
    badge: '/icons/icon.png'
  });

  // build 310 — Web Push 표준 옵션: urgency 'high' 면 OS 가 즉시 헤즈업 표시 유도
  const isUrgent = (priority === 'urgent' || priority === 'high');
  const pushOptions = {
    TTL: 86400,                              // 1일 보관 후 만료 (기본 4주 → 단축)
    urgency: isUrgent ? 'high' : 'normal'    // VAPID urgency 헤더
  } as any;

  const expiredIds: string[] = [];
  const results = await Promise.allSettled(webSubs.map(async (s) => {
    const subscription = {
      endpoint: s.endpoint,
      keys: { p256dh: s.p256dh, auth: s.auth }
    };
    try {
      await webpush.sendNotification(subscription as any, payload, pushOptions);
      // 성공 시 last_sent_at 업데이트 (비동기, 결과 기다리지 않음)
      sb.from('push_subscriptions').update({
        last_sent_at: new Date().toISOString(), last_error: null
      }).eq('id', s.id).then(() => {});
      return { ok: true, id: s.id };
    } catch (e: any) {
      const statusCode = e?.statusCode;
      // 410 Gone / 404 = 만료된 구독 → 삭제 큐
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

  // 7) 만료된 구독 일괄 삭제
  if (expiredIds.length > 0) {
    await sb.from('push_subscriptions').delete().in('id', expiredIds);
  }

  const webSent = results.filter(r => r.status === 'fulfilled' && (r.value as any).ok).length;
  const webFailed = results.length - webSent;

  // 8) 네이티브(FCM) 발송 — native_push_tokens
  let nativeSent = 0, nativeFailed = 0, nativeInvalidDeleted = 0;
  try {
    if (isFcmConfigured()) {
      let ntQuery = sb.from('native_push_tokens').select('token').eq('enabled', true);
      if (!broadcast) ntQuery = ntQuery.in('user_id', recipientIds);
      const { data: ntoks } = await ntQuery;
      const tokens = (ntoks || []).map((r: any) => r.token).filter(Boolean);
      if (tokens.length) {
        const fr = await sendFcmToTokens(tokens, { title, body: msgBody, url, tag, priority, messageId });
        nativeSent = fr.sent;
        nativeFailed = fr.failed;
        if (fr.invalidTokens.length) {
          await sb.from('native_push_tokens').delete().in('token', fr.invalidTokens);
          nativeInvalidDeleted = fr.invalidTokens.length;
        }
      }
    }
  } catch (e: any) {
    console.warn('[push] native FCM error:', e?.message);
  }

  return Response.json({
    ok: true,
    total: results.length + nativeSent + nativeFailed,
    sent: webSent + nativeSent,
    failed: webFailed + nativeFailed,
    web: { sent: webSent, failed: webFailed },
    native: { sent: nativeSent, failed: nativeFailed },
    expired_deleted: expiredIds.length,
    native_invalid_deleted: nativeInvalidDeleted
  });
}

// CORS preflight (필요 시)
export async function OPTIONS() {
  return new Response(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Authorization, Content-Type'
    }
  });
}
