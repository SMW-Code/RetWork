// Node.js runtime — 환경변수를 매 요청마다 안정적으로 읽기 위해 사용
export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

export async function POST(request: Request) {
  const apiKey = (process.env.GOOGLE_VISION_API_KEY || '').trim();

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
