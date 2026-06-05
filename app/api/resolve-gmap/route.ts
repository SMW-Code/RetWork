// Google 지도 단축 링크 (maps.app.goo.gl, goo.gl/maps) → 최종 URL 추적 + 좌표 추출
// 브라우저는 CORS 때문에 직접 redirect 추적이 불가능하므로 서버에서 대행.
// b387 — 어드민 가게 편집의 google_maps_url 자동 좌표 동기화 보조 API
export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

const SHORT_HOST_RE = /^(?:maps\.app\.goo\.gl|goo\.gl|maps\.app\.goo\.ne\.jp)$/i;
const ALLOWED_HOSTS = /^(?:www\.google\.|maps\.google\.|maps\.app\.goo\.gl|goo\.gl|google\.com|google\.[a-z.]+)/i;

function extractLatLng(url: string): { lat: number; lng: number } | null {
  if (!url) return null;
  let m: RegExpMatchArray | null;
  m = url.match(/@(-?\d+\.\d+),(-?\d+\.\d+)/);
  if (m) return { lat: parseFloat(m[1]), lng: parseFloat(m[2]) };
  m = url.match(/!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)/);
  if (m) return { lat: parseFloat(m[1]), lng: parseFloat(m[2]) };
  m = url.match(/[?&](?:q|ll|center|destination)=(-?\d+\.\d+)(?:,| )(-?\d+\.\d+)/);
  if (m) return { lat: parseFloat(m[1]), lng: parseFloat(m[2]) };
  return null;
}

export async function GET(request: Request) {
  const url = new URL(request.url).searchParams.get('url');
  if (!url) {
    return Response.json({ error: 'url query required' }, { status: 400 });
  }
  // SSRF 방지 — Google 도메인만 허용
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return Response.json({ error: 'invalid url' }, { status: 400 });
  }
  if (!ALLOWED_HOSTS.test(parsed.hostname)) {
    return Response.json({ error: 'host not allowed' }, { status: 400 });
  }

  try {
    // redirect 자동 추적 — 최종 URL을 res.url 에서 받음
    const res = await fetch(url, {
      method: 'GET',
      redirect: 'follow',
      headers: {
        // Google 지도가 모바일 UA 에서 더 정확한 redirect 줌
        'User-Agent':
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
        'Accept-Language': 'ja,en;q=0.9',
      },
    });
    const finalUrl = res.url || url;
    let coords = extractLatLng(finalUrl);
    // finalUrl에 좌표가 없으면 HTML 본문에서 시도 (place URL 의 meta/scripts 에 보통 좌표 박혀 있음)
    if (!coords) {
      try {
        const txt = await res.text();
        // HTML 안의 좌표 패턴 — preview-image 또는 APP_INITIALIZATION_STATE 등에서
        const m =
          txt.match(/"center":\s*\{?\s*"lat"\s*:\s*(-?\d+\.\d+)\s*,\s*"lng"\s*:\s*(-?\d+\.\d+)/) ||
          txt.match(/null,\s*null,\s*(-?\d+\.\d+),\s*(-?\d+\.\d+)\]/) ||
          txt.match(/@(-?\d+\.\d+),(-?\d+\.\d+)/);
        if (m) coords = { lat: parseFloat(m[1]), lng: parseFloat(m[2]) };
      } catch {
        // ignore body parse failure
      }
    }
    if (coords) {
      return Response.json({ ok: true, lat: coords.lat, lng: coords.lng, finalUrl });
    }
    return Response.json({ ok: false, finalUrl, error: 'no coords found' });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return Response.json({ ok: false, error: msg }, { status: 500 });
  }
}
