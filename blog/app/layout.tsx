import type { Metadata } from 'next';
import Link from 'next/link';
import Script from 'next/script';
import '../styles/globals.css';

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

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ja">
      <head>
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
