import { notFound } from 'next/navigation';
import Link from 'next/link';
import { getAllSlugs, getPostBySlug } from '../../../lib/posts';
import AdSlot from '../../../components/AdSlot';
import type { Metadata } from 'next';

export const dynamic = 'force-static';
export const dynamicParams = false;

export async function generateStaticParams() {
  return getAllSlugs().map((slug) => ({ slug }));
}

export async function generateMetadata(
  { params }: { params: Promise<{ slug: string }> }
): Promise<Metadata> {
  const { slug } = await params;
  const post = await getPostBySlug(slug);
  if (!post) return {};
  return {
    title: post.title,
    description: post.description || post.title,
    openGraph: {
      title: post.title,
      description: post.description || post.title,
      type: 'article',
      images: post.image ? [{ url: post.image }] : undefined,
      publishedTime: post.date,
    },
    twitter: {
      card: 'summary_large_image',
      title: post.title,
      description: post.description || post.title,
      images: post.image ? [post.image] : undefined,
    },
    alternates: { canonical: `https://blog.retwork.jp/posts/${slug}` },
  };
}

export default async function PostPage(
  { params }: { params: Promise<{ slug: string }> }
) {
  const { slug } = await params;
  const post = await getPostBySlug(slug);
  if (!post) notFound();

  return (
    <article>
      <Link href="/" style={{ fontSize: 13, color: 'var(--text-3)' }}>← 記事一覧に戻る</Link>

      <h1 className="post-hero">{post.title}</h1>

      <div className="post-meta">
        <span className="author">{post.author}</span>
        <span className="dot">·</span>
        <span>{post.date}</span>
        {post.tags && post.tags.length > 0 && (
          <>
            <span className="dot">·</span>
            {post.tags.map((t, i) => (
              <span key={t}>
                #{t}{i < post.tags!.length - 1 ? ' ' : ''}
              </span>
            ))}
          </>
        )}
      </div>

      {/* 상단 광고 */}
      <AdSlot slot="" format="horizontal" />

      <div
        className="post-body"
        dangerouslySetInnerHTML={{ __html: post.contentHtml }}
      />

      {/* 본문 하단 광고 */}
      <AdSlot slot="" format="auto" />

      <hr style={{ margin: '40px 0 24px', border: 'none', borderTop: '1px solid var(--border)' }} />

      <div style={{
        background: 'var(--surface)', borderRadius: 12, padding: '20px 22px',
        border: '1px solid var(--border)',
      }}>
        <div style={{ fontSize: 14, color: 'var(--text-2)', marginBottom: 6 }}>
          📷 レシートで家計簿、地図でコスパ店検索
        </div>
        <div style={{ fontFamily: 'var(--font-jp)', fontSize: 18, fontWeight: 700, marginBottom: 8 }}>
          RetWork（チリつも）— 日本ユーザー向け家計簿+コスパマップ
        </div>
        <div style={{ fontSize: 13, color: 'var(--text-2)', lineHeight: 1.7, marginBottom: 12 }}>
          レシートを撮影するだけで自動仕分け、コミュニティ全体のリアル価格データから「安くて美味しい店」を発見できます。
        </div>
        <a
          href="https://retwork.jp"
          target="_blank"
          rel="noopener"
          style={{
            display: 'inline-block', padding: '10px 16px',
            background: 'var(--accent)', color: '#fff',
            borderRadius: 8, fontWeight: 700, fontSize: 14,
          }}
        >
          アプリを開く →
        </a>
      </div>

      <div style={{ marginTop: 32, textAlign: 'center' }}>
        <Link href="/" style={{ fontSize: 13, color: 'var(--text-3)' }}>← 記事一覧に戻る</Link>
      </div>
    </article>
  );
}
