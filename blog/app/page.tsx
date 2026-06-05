import Link from 'next/link';
import { getAllPosts } from '../lib/posts';

export const dynamic = 'force-static';

export default function HomePage() {
  const posts = getAllPosts();
  return (
    <>
      <section style={{ marginBottom: 32 }}>
        <h1 style={{ fontFamily: 'var(--font-jp)', fontSize: 26, margin: '8px 0 6px' }}>
          コスパで選ぶ日本のグルメ&家計簿術
        </h1>
        <p style={{ color: 'var(--text-2)', fontSize: 14, lineHeight: 1.7, margin: 0 }}>
          実際のレシートで検証した東京の名店レビューと、家計簿アプリ「
          <a href="https://retwork.jp" target="_blank" rel="noopener">RetWork（チリつも）</a>
          」の使い方を発信。
        </p>
      </section>

      <section>
        {posts.length === 0 && (
          <div style={{ color: 'var(--text-3)', textAlign: 'center', padding: '60px 20px' }}>
            まだ記事がありません。
          </div>
        )}
        {posts.map((p) => (
          <Link key={p.slug} href={`/posts/${p.slug}`} style={{ display: 'block', color: 'inherit' }}>
            <article className="post-card">
              <h2>{p.title}</h2>
              <div className="meta">
                {p.date} {p.author && <>· {p.author}</>}
              </div>
              {p.description && <p className="excerpt">{p.description}</p>}
              {p.tags && p.tags.length > 0 && (
                <div className="tags">
                  {p.tags.map((t) => (
                    <span key={t} className="tag">#{t}</span>
                  ))}
                </div>
              )}
            </article>
          </Link>
        ))}
      </section>
    </>
  );
}
