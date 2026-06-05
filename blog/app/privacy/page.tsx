import Link from 'next/link';

export const dynamic = 'force-static';
export const metadata = { title: 'プライバシーポリシー' };

export default function PrivacyPage() {
  return (
    <article>
      <Link href="/" style={{ fontSize: 13, color: 'var(--text-3)' }}>← 記事一覧</Link>
      <h1 className="post-hero">プライバシーポリシー</h1>

      <div className="post-body">
        <p>
          RetWork Blog（以下「当ブログ」）は、訪問者のプライバシー保護を重視しています。
          本ポリシーでは、当ブログにおける個人情報の取扱いについて定めます。
        </p>

        <h2>1. 取得する情報</h2>
        <p>
          当ブログでは、訪問者の閲覧履歴・IPアドレス・ブラウザ情報などを
          Cookieやアクセス解析ツールを通じて自動的に収集する場合があります。
        </p>

        <h2>2. Google AdSense について</h2>
        <p>
          当ブログでは、第三者配信の広告サービス「Google AdSense」を利用しています。
          Google などの第三者広告配信事業者は、訪問者の興味に応じた広告を表示するために
          Cookie を使用することがあります。
        </p>
        <p>
          Cookie を無効にする方法、および Google AdSense に関する詳細は、
          <a href="https://policies.google.com/technologies/ads" target="_blank" rel="noopener">
            Google 広告に関するポリシー
          </a>
          をご覧ください。
        </p>

        <h2>3. アクセス解析ツール</h2>
        <p>
          当ブログでは、サイト改善のためにアクセス解析ツールを使用する場合があります。
          これらのツールはトラフィックデータの収集のために Cookie を使用しますが、
          個人を特定する情報は含みません。
        </p>

        <h2>4. 個人情報の第三者提供</h2>
        <p>
          当ブログは、法令に基づく場合を除き、個人情報を本人の同意なく
          第三者に提供することはありません。
        </p>

        <h2>5. 免責事項</h2>
        <p>
          当ブログに掲載される情報は、可能な限り正確であるよう努めていますが、
          完全性・正確性・有用性を保証するものではありません。
          掲載情報を利用したことによる損害について、当ブログは責任を負いません。
        </p>

        <h2>6. 著作権</h2>
        <p>
          当ブログに掲載されている全てのコンテンツの著作権は、
          原則として運営者または各権利者に帰属します。
          無断転載・複製を禁じます。引用の際は出典を明記してください。
        </p>

        <h2>7. ポリシーの変更</h2>
        <p>
          本ポリシーは予告なく変更される場合があります。最新の内容は本ページにて随時更新します。
        </p>

        <p style={{ fontSize: 13, color: 'var(--text-3)', marginTop: 24 }}>
          制定日: 2026年6月5日
        </p>
      </div>
    </article>
  );
}
