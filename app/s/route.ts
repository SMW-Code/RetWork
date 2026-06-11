import { NextRequest } from 'next/server';

/* ════════════════════════════════════════════════════════════════════
   /s — 공유 링크 페이지 (b444)
   카카오톡/LINE/X 등 메신저 크롤러에게 가게·메뉴별 OG 메타태그를 제공
   → 받은 사람에게 "터치하면 이동하는" 링크 프리뷰 카드(풀 카드 이미지)가 생성됨
   실제 사용자가 열면 즉시 retwork.jp 로 리다이렉트 (레퍼럴 코드 보존)

   쿼리:
     i = OG 이미지. store-photos 버킷 내 경로(share/xxx.jpg) 또는 전체 https URL
     t = 제목(가게명/메뉴명)
     d = 설명(주소·가격 등)
     r = 레퍼럴 코드 → 리다이렉트 시 retwork.jp/?ref=r 로 보냄
   이미지는 자체 Supabase 스토리지/retwork.jp 만 허용 (프리뷰 스푸핑 방지)
═══════════════════════════════════════════════════════════════════ */

export const dynamic = 'force-dynamic';

const SUPABASE_PUBLIC =
  'https://fkvfbxfgidrvymoftkdd.supabase.co/storage/v1/object/public/store-photos/';
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

  // 이미지 — 경로면 Supabase URL 조립, 전체 URL이면 호스트 검증
  let img = sp.get('i') || '';
  if (img && !/^https?:\/\//.test(img)) {
    img = SUPABASE_PUBLIC + img.replace(/^\/+/, '');
  }
  try {
    const u = new URL(img);
    if (u.protocol !== 'https:' || !ALLOWED_IMG_HOSTS.includes(u.hostname)) img = '';
  } catch {
    img = '';
  }
  if (!img) img = FALLBACK_IMG;

  // 리다이렉트 목적지 — 레퍼럴 코드 보존
  const ref = (sp.get('r') || '').replace(/[^A-Za-z0-9]/g, '').slice(0, 16);
  const dest = ref ? 'https://retwork.jp/?ref=' + ref : 'https://retwork.jp/';

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
<meta http-equiv="refresh" content="0;url=${esc(dest)}">
</head>
<body style="font-family:sans-serif;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;">
<script>location.replace(${JSON.stringify(dest)});</script>
<p><a href="${esc(dest)}">RetWork（チリつも）へ移動中…</a></p>
</body>
</html>`;

  return new Response(html, {
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'public, max-age=300',
    },
  });
}
