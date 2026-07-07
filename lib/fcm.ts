// ════════════════════════════════════════════════════════════════════════════
// FCM HTTP v1 발송 (b601) — 의존성 없음 (Node crypto 로 JWT 서명 → 액세스 토큰 → 발송)
//
//   네이티브(Capacitor) 앱은 web-push 미수신 → FCM 으로 발송.
//   env: FIREBASE_SERVICE_ACCOUNT = Firebase 서비스 계정 JSON 전체(문자열)
//        (project_id, client_email, private_key 포함)
//
//   사용: import { sendFcmToTokens, isFcmConfigured } from '@/lib/fcm';
// ════════════════════════════════════════════════════════════════════════════

import crypto from 'crypto';

type ServiceAccount = { project_id: string; client_email: string; private_key: string };

let _sa: ServiceAccount | null | undefined; // undefined=미조회, null=미설정
function getServiceAccount(): ServiceAccount | null {
  if (_sa !== undefined) return _sa;
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT || '';
  if (!raw) { _sa = null; return null; }
  try {
    const obj = JSON.parse(raw);
    let pk = obj.private_key || '';
    // Vercel 환경변수에 \n 이 이스케이프되어 들어간 경우 실제 개행으로 복원
    if (pk.indexOf('\\n') >= 0) pk = pk.replace(/\\n/g, '\n');
    _sa = { project_id: obj.project_id, client_email: obj.client_email, private_key: pk };
    if (!_sa.project_id || !_sa.client_email || !_sa.private_key) _sa = null;
  } catch (e) {
    console.warn('[fcm] service account parse failed:', (e as any)?.message);
    _sa = null;
  }
  return _sa;
}

export function isFcmConfigured(): boolean { return !!getServiceAccount(); }

function base64url(input: Buffer | string): string {
  return Buffer.from(input).toString('base64').replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}

// 액세스 토큰 캐시 (모듈 스코프 — 1시간 유효, 만료 60초 전 재발급)
let _tokenCache: { token: string; exp: number } | null = null;
async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (_tokenCache && _tokenCache.exp > now + 60) return _tokenCache.token;

  const header = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64url(JSON.stringify({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }));
  const signingInput = header + '.' + claims;
  const signer = crypto.createSign('RSA-SHA256');
  signer.update(signingInput);
  const signature = base64url(signer.sign(sa.private_key));
  const jwt = signingInput + '.' + signature;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  const data: any = await res.json();
  if (!res.ok || !data.access_token) {
    throw new Error('token exchange failed: ' + JSON.stringify(data));
  }
  _tokenCache = { token: data.access_token, exp: now + (data.expires_in || 3600) };
  return data.access_token;
}

export type FcmPayload = {
  title: string;
  body: string;
  url?: string;
  tag?: string;
  priority?: string;   // 'urgent' | 'high' | 'normal'
  messageId?: string | null;
};
export type FcmResult = { sent: number; failed: number; invalidTokens: string[]; configured: boolean };

// 여러 토큰에 발송 (v1 은 멀티캐스트 미지원 → 토큰별 병렬 발송)
export async function sendFcmToTokens(tokens: string[], payload: FcmPayload): Promise<FcmResult> {
  const sa = getServiceAccount();
  if (!sa) return { sent: 0, failed: 0, invalidTokens: [], configured: false };
  if (!tokens || tokens.length === 0) return { sent: 0, failed: 0, invalidTokens: [], configured: true };

  let accessToken: string;
  try {
    accessToken = await getAccessToken(sa);
  } catch (e: any) {
    console.warn('[fcm] access token error:', e?.message);
    return { sent: 0, failed: tokens.length, invalidTokens: [], configured: true };
  }

  const endpoint = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;
  const invalidTokens: string[] = [];
  let sent = 0, failed = 0;

  await Promise.allSettled(tokens.map(async (tk) => {
    const message = {
      message: {
        token: tk,
        notification: { title: payload.title, body: payload.body },
        // FCM data 값은 모두 문자열이어야 함
        data: {
          url: payload.url || '/',
          tag: payload.tag || 'retwork-msg',
          messageId: payload.messageId ? String(payload.messageId) : '',
        },
        android: {
          priority: 'high',   // 즉시 전달 (도즈 상태에서도 깨움)
          notification: {
            channel_id: 'retwork_high',   // 앱에서 생성한 고중요도 채널 → 헤즈업 배너
            notification_priority: 'PRIORITY_HIGH',
            default_sound: true,
            default_vibrate_timings: true,
          },
        },
      },
    };
    const res = await fetch(endpoint, {
      method: 'POST',
      headers: { Authorization: 'Bearer ' + accessToken, 'Content-Type': 'application/json' },
      body: JSON.stringify(message),
    });
    if (res.ok) { sent++; return; }
    failed++;
    let err: any = {};
    try { err = await res.json(); } catch (_) {}
    const status = (err && err.error && err.error.status) || '';
    // 만료/무효 토큰 → 삭제 큐
    if (res.status === 404 || status === 'NOT_FOUND' || status === 'UNREGISTERED' || status === 'INVALID_ARGUMENT') {
      invalidTokens.push(tk);
    }
    console.warn('[fcm] send failed:', res.status, status);
  }));

  return { sent, failed, invalidTokens, configured: true };
}
