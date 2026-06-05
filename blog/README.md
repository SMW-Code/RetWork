# RetWork Blog

> **`blog.retwork.jp`** — 日本市場向け家計簿アプリ RetWork（チリつも）の公式ブログ.
> AdSense 심사 통과 + SEO 트래픽을 위한 Next.js 정적 블로그.

---

## 폴더 구조

```
blog/
├─ app/
│  ├─ layout.tsx              ← 전체 레이아웃 (헤더/푸터/AdSense)
│  ├─ page.tsx                ← 홈 (글 목록)
│  ├─ posts/[slug]/page.tsx   ← 개별 글 페이지
│  ├─ about/page.tsx          ← 운영자 소개
│  ├─ privacy/page.tsx        ← 프라이버시 (AdSense 필수)
│  ├─ terms/page.tsx          ← 이용 약관 (AdSense 필수)
│  ├─ robots.txt/route.ts     ← robots.txt
│  └─ sitemap.xml/route.ts    ← sitemap.xml
├─ components/
│  └─ AdSlot.tsx              ← AdSense 슬롯 컴포넌트
├─ lib/
│  └─ posts.ts                ← Markdown → HTML 변환
├─ posts/
│  └─ kitakata-shokudo-jimbocho.md   ← 첫 글
├─ public/
│  └─ images/                 ← 사진 폴더
├─ styles/
│  └─ globals.css             ← 미니멀 일본어 에디토리얼 디자인
└─ ...
```

---

## 로컬 개발

```bash
cd blog
npm install
npm run dev
# → http://localhost:3001
```

본 앱 (`retwork.jp`) 의 포트(3000)와 분리하기 위해 **3001 포트** 사용.

---

## 새 글 작성 방법

1. `posts/` 폴더에 `<slug>.md` 파일 생성
2. front matter 작성 (kitakata-shokudo-jimbocho.md 참고):
   ```markdown
   ---
   title: "기사 제목"
   date: "2026-06-05"
   description: "기사 요약 (SEO meta description)"
   image: "/images/<slug>/main.jpg"
   tags: ["神保町", "ラーメン"]
   author: "RetWork編集部"
   ---

   본문 시작...
   ```
3. 본문 Markdown 작성 (GFM 지원: 표/체크박스/링크 등)
4. `public/images/<slug>/` 폴더에 사진 추가
5. `git push` → Vercel 자동 배포

---

## Vercel 배포 + 도메인 연결

### 1. Vercel 에 새 프로젝트 추가
1. https://vercel.com/new 에서 RetWork 저장소 import
2. **Root Directory**: `blog` 로 지정 (중요!)
3. Framework: Next.js 자동 감지
4. Deploy

### 2. 도메인 연결 (`blog.retwork.jp`)
1. Vercel 프로젝트 → Settings → Domains → `blog.retwork.jp` 추가
2. 도메인 등록 회사 DNS 에 CNAME 레코드 추가:
   ```
   Type:  CNAME
   Name:  blog
   Value: cname.vercel-dns.com
   TTL:   3600
   ```
3. DNS 전파 후 (수분~수시간) HTTPS 자동 발급

### 3. 환경 변수 설정 (AdSense 통과 후)
Vercel → Settings → Environment Variables:
```
NEXT_PUBLIC_ADSENSE_CLIENT = ca-pub-XXXXXXXXXXXXXXXX
```

---

## Google AdSense 심사 신청 흐름

1. `blog.retwork.jp` 정상 배포 확인
2. 최소 5~10편 작성 권장 (현재 1편 → 더 작성 필요)
3. https://www.google.com/adsense 에서 사이트 추가
4. AdSense 가 안내하는 코드를 `layout.tsx` 에 이미 포함된 것으로 대체 (현재 NEXT_PUBLIC_ADSENSE_CLIENT 기반)
5. 심사 요청 → 평균 2-4주 대기
6. 통과 후 `NEXT_PUBLIC_ADSENSE_CLIENT` 환경변수 설정 → 광고 자동 표시

---

## SEO 체크리스트

- ✅ 각 글마다 `<title>`, `<meta description>` (front matter 기반)
- ✅ OpenGraph + Twitter Card 태그
- ✅ `sitemap.xml` 자동 생성 (`/sitemap.xml`)
- ✅ `robots.txt` 자동 생성 (`/robots.txt`)
- ✅ canonical URL 설정
- ✅ 정적 페이지 생성 (`force-static`) — 빠른 색인

Search Console 에서 sitemap 제출:
```
https://blog.retwork.jp/sitemap.xml
```

---

## 향후 추가 작업 (선택)

- [ ] 카테고리/태그별 페이지 (`/tags/<tag>`)
- [ ] 검색 기능 (정적 인덱스)
- [ ] 이미지 최적화 (Next/Image)
- [ ] 다국어 (한국어 버전)
- [ ] 댓글 시스템 (Giscus 등)
- [ ] RSS feed (`/feed.xml`)

---

## 라이선스

© 2026 RetWork (チリつも). All rights reserved.
