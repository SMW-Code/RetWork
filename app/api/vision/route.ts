// Node.js runtime — Vercel 환경변수를 매 요청마다 안정적으로 읽기 위해 사용
export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

// 여러 후보 이름을 순서대로 시도 — 어느 이름으로 등록돼 있어도 동작
const KEY_CANDIDATES = [
  'GOOGLE_VISION_API_KEY',
  'VISION_KEY',
  'VISION_API_KEY',
  'GOOGLE_VISION_KEY',
  'GCP_VISION_KEY',
];

function pickApiKey(): string | null {
  for (const name of KEY_CANDIDATES) {
    const raw = process.env[name];
    if (raw && raw.trim().length > 0) return raw.trim();
  }
  return null;
}

export async function POST(request: Request) {
  const apiKey = pickApiKey();

  if (!apiKey) {
    return Response.json(
      { error: { message: 'Google Vision API key is not configured on the server.' } },
      { status: 500 }
    );
  }

  let body: { base64Image?: string };
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: { message: 'Invalid JSON body.' } }, { status: 400 });
  }

  if (!body || !body.base64Image) {
    return Response.json({ error: { message: 'base64Image is required.' } }, { status: 400 });
  }

  const upstream = await fetch(
    'https://vision.googleapis.com/v1/images:annotate?key=' + encodeURIComponent(apiKey),
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        requests: [
          {
            image: { content: body.base64Image },
            features: [{ type: 'TEXT_DETECTION', maxResults: 1 }],
          },
        ],
      }),
    }
  );

  const data = await upstream.json();
  return Response.json(data, { status: upstream.status });
}
