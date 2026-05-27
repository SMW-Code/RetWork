export const runtime = 'edge';

export async function POST(request: Request) {
  const apiKey = process.env.GOOGLE_VISION_API_KEY;

  if (!apiKey) {
    return Response.json(
      { error: { message: 'Google Vision API key is not configured on the server.' } },
      { status: 500 }
    );
  }

  const { base64Image } = await request.json();

  if (!base64Image) {
    return Response.json(
      { error: { message: 'base64Image is required.' } },
      { status: 400 }
    );
  }

  const upstream = await fetch(
    'https://vision.googleapis.com/v1/images:annotate?key=' + apiKey,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        requests: [{
          image: { content: base64Image },
          features: [{ type: 'TEXT_DETECTION', maxResults: 1 }],
        }],
      }),
    }
  );

  const data = await upstream.json();
  return Response.json(data, { status: upstream.status });
}
