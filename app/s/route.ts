import { NextRequest } from 'next/server';

/* ════════════════════════════════════════════════════════════════════
   /s — 공유 링크 페이지 (b441)
   카카오톡/LINE/X 등 메신저 크롤러에게 가게·메뉴별 OG 메타태그를 제공
   → 받은 사람에게 "터치하면 이동하는" 링크 프리뷰 카드가 생성됨
   실제 사용자가 열면 즉시 retwork.jp 로 리다이렉트

   쿼리: t=제목(가게명/메뉴명)  d=설명(가격·평점 등)  i=이미지URL
   이미지는 자체 Supabase 스토리지/retwork.jp 만 허용 (스푸핑 방지)
═══════════════════════════════════════════════════════════════════ */

export const dynamic = 'force-dynamic';

const DEST = 'https://retwork.jp/';
const FALLBACK_IMG = 'https://retwork.jp/icons/icon-512.png';
const ALLOWED_IMG_HOSTS = ['fkvfbxfgidrvymoftkdd.supabase.co', 'retwork.jp'];

function esc(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

export async function GET(req: NextRequest) {
  const sp = req.nextUrl.searchParams;
  const title = (sp.get('t') || 'RetWork（チリつも）').slice(0, 80);
  const desc = (sp.get('d') || 'レシートでお得を共有 — RetWork（チリつも）').slice(0, 160);

  let img = sp.get('i') || '';
  try {
    const u = new URL(img);
    if (u.protocol !== 'https:' || !ALLOWED_IMG_HOSTS.includes(u.hostname)) img = '';
  } catch {
    img = '';
  }
  if (!img) img = FALLBACK_IMG;

  // 페이지 자신의 og:url (크롤러가 캐시 키로 사용)
  const selfUrl = 'https://retwork.jp/s?' + sp.toString();

  const html = `<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(title)} | RetWork</title>
<meta property="og:type" content="website">
<meta property="og:site_name" content="RetWork（チリつも）">
<meta property="og:title" content="${esc(title)}">
<meta property="og:description" content="${esc(desc)}">
<meta property="og:image" content="${esc(img)}">
<meta property="og:url" content="${esc(selfUrl)}">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${esc(title)}">
<meta name="twitter:description" content="${esc(desc)}">
<meta name="twitter:image" content="${esc(img)}">
<meta name="robots" content="noindex">
<meta http-equiv="refresh" content="0;url=${DEST}">
</head>
<body style="font-family:sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;">
<script>location.replace(${JSON.stringify(DEST)});</script>
<p><a href="${DEST}">RetWork（チリつも）へ移動中…</a></p>
</body>
</html>`;

  return new Response(html, {
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      // 크롤러 프리뷰 캐시 5분 — 같은 링크 반복 공유 시 빠르게
      'Cache-Control': 'public, max-age=300',
    },
  });
}
