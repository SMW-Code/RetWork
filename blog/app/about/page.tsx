import Link from 'next/link';

export const dynamic = 'force-static';
export const metadata = { title: '運営者について' };

export default function AboutPage() {
  return (
    <article>
      <Link href="/" style={{ fontSize: 13, color: 'var(--text-3)' }}>← 記事一覧</Link>
      <h1 className="post-hero">運営者について</h1>

      <div className="post-body">
        <p>
          RetWork Blog は、日本市場向け家計簿+コスパマップアプリ
          <a href="https://retwork.jp" target="_blank" rel="noopener"> RetWork（チリつも）</a>
          の運営チームが発信する公式ブログです。
        </p>

        <h2>編集方針</h2>
        <p>
          実際にユーザーが投稿したレシート・写真・コミュニティデータをもとに、
          東京近郊のコスパ店舗を取材・実食レビューしています。広告主からの
          金銭的・物品的見返りを受けていない店舗情報のみを掲載しています。
        </p>

        <h2>取り扱いトピック</h2>
        <ul>
          <li>東京近郊のコスパランチ・夕食レビュー</li>
          <li>家計簿アプリ RetWork の使い方ガイド</li>
          <li>レシートから読み解く節約術</li>
          <li>コミュニティ価格データを活かしたグルメ探索</li>
        </ul>

        <h2>お問い合わせ</h2>
        <p>
          記事内容に関するお問い合わせは、RetWork アプリ内の
          「お問い合わせ」フォームをご利用ください。
        </p>
      </div>
    </article>
  );
}
