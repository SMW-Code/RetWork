// Node.js runtime — Edge runtime은 Vercel "Sensitive" 환경변수를 가끔 빈 값으로 반환해서
// 안정성을 위해 Node로 명시 지정. 키 발견 여부도 진단용 로그로 남김.
export const runtime = 'nodejs';
export const dynamic = 'force-dynamic'; // 빌드 캐시에 키가 박히지 않도록 매 요청 평가

export async function POST(request: Request) {
  const apiKey = process.env.GOOGLE_VISION_API_KEY;

  // 진단 로그 — Vercel Functions 로그에서 확인
  console.log('[vision] env key present?', Boolean(apiKey), 'length:', apiKey ? apiKey.length : 0);

  if (!apiKey) {
    return Response.json(
      {
        error: {
          message: 'Google Vision API key is not configured on the server.',
          hint: 'GOOGLE_VISION_API_KEY env var missing or empty. Check Vercel Project Settings → Environment Variables.',
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
    'https://vision.googleapis.com/v1/images:annotate?key=' + encodeURIComponent(apiKey.trim()),
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
