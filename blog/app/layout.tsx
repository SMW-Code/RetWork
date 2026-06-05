import type { Metadata } from 'next';
import Link from 'next/link';
import Script from 'next/script';

const SITE = {
  title: 'RetWork Blog — コスパで選ぶ日本のグルメ&家計簿術',
  description: '日本のコスパランチ、レシートで見つけた名店、家計簿アプリ RetWork（チリつも）の使い方を発信。神保町・新宿・渋谷など東京エリアのリアルな店舗レビュー。',
  url: 'https://blog.retwork.jp',
};

const ADSENSE_CLIENT = process.env.NEXT_PUBLIC_ADSENSE_CLIENT || '';

export const metadata: Metadata = {
  metadataBase: new URL(SITE.url),
  title: { default: SITE.title, template: '%s | RetWork Blog' },
  description: SITE.description,
  openGraph: {
    title: SITE.title,
    description: SITE.description,
    type: 'website',
    locale: 'ja_JP',
    siteName: 'RetWork Blog',
  },
  twitter: {
    card: 'summary_large_image',
    title: SITE.title,
    description: SITE.description,
  },
  robots: { index: true, follow: true },
  alternates: { canonical: SITE.url },
};

/* CSS — 외부 파일 대신 inline 으로 layout 에 삽입 (PostCSS pipeline 의존 제거) */
const CSS = `
:root {
  --bg: #fbfaf7;
  --surface: #ffffff;
  --text-1: #1c1c1c;
  --text-2: #4a4a4a;
  --text-3: #8a8a8a;
  --border: #e6e2d8;
  --border-mid: #d6d2c4;
  --accent: #16a87a;
  --accent-dark: #0f7a59;
  --tag-bg: #f0ede4;
  --link: #1f6db3;
  --font-jp: 'Hiragino Mincho ProN', 'Yu Mincho', 'Noto Serif JP', serif;
  --font-ui: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Noto Sans JP', 'Yu Gothic UI', sans-serif;
  --max-w: 720px;
}
* { box-sizing: border-box; }
html, body { margin: 0; padding: 0; background: var(--bg); color: var(--text-1); }
body { font-family: var(--font-ui); line-height: 1.75; font-size: 16px; -webkit-font-smoothing: antialiased; -webkit-text-size-adjust: 100%; }
a { color: var(--link); text-decoration: none; transition: opacity .15s; }
a:hover { opacity: .7; }
img { max-width: 100%; height: auto; display: block; border-radius: 8px; }
.container { max-width: var(--max-w); margin: 0 auto; padding: 28px 20px 80px; }
.site-header { border-bottom: 1px solid var(--border); background: var(--surface); position: sticky; top: 0; z-index: 10; }
.site-header-inner { max-width: var(--max-w); margin: 0 auto; padding: 14px 20px; display: flex; align-items: center; justify-content: space-between; }
.site-logo { font-family: var(--font-jp); font-size: 18px; font-weight: 800; color: var(--text-1); letter-spacing: -.3px; }
.site-logo span { color: var(--accent); }
.site-nav a { font-size: 13px; color: var(--text-2); margin-left: 16px; }
.post-card { background: var(--surface); border: 1px solid var(--border); border-radius: 12px; padding: 18px 20px; margin-bottom: 14px; transition: border-color .15s, transform .15s; }
.post-card:hover { border-color: var(--accent); transform: translateY(-1px); }
.post-card h2 { font-family: var(--font-jp); font-size: 19px; font-weight: 700; margin: 0 0 6px; line-height: 1.4; color: var(--text-1); }
.post-card .meta { font-size: 12px; color: var(--text-3); margin-bottom: 8px; }
.post-card .excerpt { font-size: 14px; color: var(--text-2); line-height: 1.7; margin: 0; }
.post-card .tags { margin-top: 10px; display: flex; flex-wrap: wrap; gap: 6px; }
.post-card .tag { font-size: 11px; padding: 2px 9px; border-radius: 10px; background: var(--tag-bg); color: var(--text-2); font-weight: 600; }
.post-hero { font-family: var(--font-jp); font-size: 28px; font-weight: 800; line-height: 1.4; letter-spacing: -.5px; margin: 18px 0 10px; color: var(--text-1); }
.post-meta { font-size: 13px; color: var(--text-3); border-bottom: 1px solid var(--border); padding-bottom: 16px; margin-bottom: 24px; }
.post-meta .author { color: var(--text-2); font-weight: 700; }
.post-meta .dot { margin: 0 6px; }
.post-body { font-size: 16px; line-height: 1.85; color: var(--text-1); }
.post-body h2 { font-family: var(--font-jp); font-size: 22px; font-weight: 700; margin: 36px 0 14px; padding-top: 8px; border-top: 2px solid var(--accent); padding-left: 0; }
.post-body h3 { font-size: 17px; font-weight: 700; margin: 28px 0 10px; color: var(--text-1); }
.post-body p { margin: 0 0 16px; }
.post-body img { margin: 20px auto; }
.post-body figure { margin: 24px 0; }
.post-body figure figcaption { font-size: 12px; color: var(--text-3); text-align: center; margin-top: 6px; }
.post-body ul, .post-body ol { padding-left: 24px; margin: 0 0 16px; }
.post-body li { margin-bottom: 6px; }
.post-body blockquote { border-left: 4px solid var(--accent); margin: 20px 0; padding: 8px 16px; background: var(--surface); color: var(--text-2); border-radius: 4px; }
.post-body table { width: 100%; border-collapse: collapse; margin: 18px 0; font-size: 14px; }
.post-body th, .post-body td { border: 1px solid var(--border); padding: 8px 12px; text-align: left; }
.post-body th { background: var(--tag-bg); font-weight: 700; }
.post-body code { background: var(--tag-bg); padding: 2px 6px; border-radius: 4px; font-size: 14px; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
.post-body hr { border: none; border-top: 1px solid var(--border); margin: 32px 0; }
.ad-slot { margin: 32px 0; padding: 18px; background: var(--surface); border: 1px dashed var(--border-mid); border-radius: 8px; text-align: center; font-size: 11px; color: var(--text-3); }
.site-footer { margin-top: 60px; padding: 28px 20px; border-top: 1px solid var(--border); text-align: center; font-size: 12px; color: var(--text-3); background: var(--surface); }
.site-footer a { color: var(--text-2); margin: 0 8px; }
@media (max-width: 600px) {
  body { font-size: 15px; }
  .container { padding: 20px 16px 60px; }
  .post-hero { font-size: 23px; }
  .post-body h2 { font-size: 19px; }
}
`;

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ja">
      <head>
        <style dangerouslySetInnerHTML={{ __html: CSS }} />
        {ADSENSE_CLIENT && (
          <Script
            id="adsense"
            async
            strategy="afterInteractive"
            src={`https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=${ADSENSE_CLIENT}`}
            crossOrigin="anonymous"
          />
        )}
      </head>
      <body>
        <header className="site-header">
          <div className="site-header-inner">
            <Link href="/" className="site-logo">
              RetWork<span>.blog</span>
            </Link>
            <nav className="site-nav">
              <Link href="/">記事一覧</Link>
              <a href="https://retwork.jp" target="_blank" rel="noopener">アプリ</a>
            </nav>
          </div>
        </header>

        <main className="container">{children}</main>

        <footer className="site-footer">
          <div>© 2026 RetWork (チリつも). All rights reserved.</div>
          <div style={{ marginTop: 8 }}>
            <Link href="/about">運営者</Link>
            <Link href="/privacy">プライバシーポリシー</Link>
            <Link href="/terms">利用規約</Link>
            <a href="https://retwork.jp" target="_blank" rel="noopener">RetWork アプリ</a>
          </div>
        </footer>
      </body>
    </html>
  );
}
