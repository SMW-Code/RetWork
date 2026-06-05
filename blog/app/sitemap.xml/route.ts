import { getAllPosts } from '../../lib/posts';

export const dynamic = 'force-static';

const SITE = 'https://blog.retwork.jp';

export function GET() {
  const posts = getAllPosts();
  const staticUrls = ['', 'about', 'privacy', 'terms'];

  const items = [
    ...staticUrls.map((p) => `<url><loc>${SITE}${p ? '/' + p : '/'}</loc><changefreq>monthly</changefreq><priority>${p === '' ? '1.0' : '0.5'}</priority></url>`),
    ...posts.map((p) => `<url><loc>${SITE}/posts/${p.slug}</loc><lastmod>${p.date}</lastmod><changefreq>monthly</changefreq><priority>0.8</priority></url>`),
  ].join('\n  ');

  const body = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  ${items}
</urlset>`;
  return new Response(body, {
    headers: { 'Content-Type': 'application/xml; charset=utf-8' },
  });
}
