// Node.js runtime — Edge runtime은 Vercel "Sensitive" 환경변수를 가끔 빈 값으로 반환해서
// 안정성을 위해 Node로 명시 지정. 키 발견 여부도 진단용 로그로 남김.
export const runtime = 'nodejs';
export const dynamic = 'force-dynamic'; // 빌드 캐시에 키가 박히지 않도록 매 요청 평가

// 여러 후보 이름을 순서대로 시도 — Vercel에서 특정 이름이 안 잡히는 경우 우회
const KEY_CANDIDATES = [
  'GOOGLE_VISION_API_KEY',
  'VISION_KEY',
  'VISION_API_KEY',
  'GOOGLE_VISION_KEY',
  'GCP_VISION_KEY',
];

function pickApiKey(): { key: string | null; source: string; tried: Record<string, number> } {
  const tried: Record<string, number> = {};
  for (const name of KEY_CANDIDATES) {
    const raw = process.env[name];
    const len = raw ? raw.trim().length : 0;
    tried[name] = len;
    if (len > 0) return { key: raw!.trim(), source: name, tried };
  }
  return { key: null, source: '', tried };
}

export async function POST(request: Request) {
  const { key, source, tried } = pickApiKey();

  // 진단 로그 — Vercel Functions 로그에서 확인 가능
  console.log('[vision] picked source:', source || '(none)', 'tried lengths:', JSON.stringify(tried));

  if (!key) {
    // 환경변수 시스템이 통째로 깨졌는지 확인 — 다른 키도 같이 점검
    const otherKnown = {
      OPENAI_API_KEY: (process.env.OPENAI_API_KEY || '').length,
      NODE_ENV: process.env.NODE_ENV || '',
      VERCEL: process.env.VERCEL || '',
      VERCEL_ENV: process.env.VERCEL_ENV || '',
    };
    return Response.json(
      {
        error: {
          message: 'Google Vision API key is not configured on the server.',
          hint: 'Tried env vars: ' + KEY_CANDIDATES.join(', ') + '. Add one in Vercel Project Settings → Environment Variables and Redeploy without cache.',
          tried,
          system: otherKnown,
        },
      },
      { status: 500 }
    );
  }

  let body: any;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: { message: 'Invalid JSON body.' } }, { status: 400 });
  }

  const { base64Image } = body || {};
  if (!base64Image) {
    return Response.json({ error: { message: 'base64Image is required.' } }, { status: 400 });
  }

  const upstream = await fetch(
    'https://vision.googleapis.com/v1/images:annotate?key=' + encodeURIComponent(key),
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        requests: [
          {
            image: { content: base64Image },
            features: [{ type: 'TEXT_DETECTION', maxResults: 1 }],
          },
        ],
      }),
    }
  );

  const data = await upstream.json();
  return Response.json(data, { status: upstream.status });
}
