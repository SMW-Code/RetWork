# RetWork 블로그 작성 가이드

> 두 블로그에 새 글을 올릴 때 **SEO 빠짐없이** 작성하는 규칙.
> 핵심 원칙: **민우는 내용만 전달 → Claude가 SEO·포맷·사이트맵 등록까지 완성**.
> 작성: 2026-06-09

---

## 0. 두 블로그는 서로 다름 (헷갈리지 말 것)

| | 🍜 그루메 블로그 | 💰 절약 블로그 |
|---|---|---|
| 주소 | `blog.retwork.jp` | `retwork.jp/blog` |
| 정체 | Next.js (마크다운 기반) | 정적 HTML |
| 저장소 | **별도 레포** `retwork-blog` | RetWork 메인 레포 `public/blog/` |
| 로컬 경로 | `C:\Users\Minwoo\Desktop\retwork-blog` | `C:\Users\Minwoo\Desktop\receiptiq\public\blog` |
| SEO 방식 | **자동** (frontmatter) | **수동** (HTML에 직접) |
| 사이트맵 | **자동** (글 추가 시 자동 등록) | **수동** (`public/sitemap.xml` 편집) |
| 배포 브랜치 | retwork-blog 레포 `main` | RetWork `main` |

---

## 1. 🍜 그루메 블로그 (blog.retwork.jp)

### 민우가 줄 것
- 가게 이름 / 위치 (예: 神保町)
- 먹은 메뉴 + 가격
- 솔직 평가 (별점, 좋았던 점 / 아쉬운 점)
- 방문 날짜
- 사진 파일 (있으면) — 없으면 텍스트만으로도 가능
- 본문은 **메모만 줘도 됨** (Claude가 일본어로 다듬어 작성)

### Claude가 만드는 것
`retwork-blog/posts/<슬러그>.md` 파일, frontmatter 채워서:
```yaml
---
title: "기사 제목 (일본어)"
date: "YYYY-MM-DD"
description: "검색 결과에 나올 설명문 — SEO 핵심, 120자 내외"
image: "/images/<슬러그>/main.jpg"
tags: ["지역", "장르", "키워드"]
author: "RetWork編集部"
---
(본문 마크다운…)
```
- → title·description·OG·트위터·canonical **자동 생성**
- → **sitemap.xml 자동 등록**
- 이미지는 `retwork-blog/public/images/<슬러그>/` 에 넣음

### 배포
```bash
cd C:\Users\Minwoo\Desktop\retwork-blog
git add -A
git commit -m "post: <기사 제목>"
git push origin main      # → blog.retwork.jp 자동 빌드
```
> 그루메 블로그는 RetWork dev/prod와 **무관** (별도 레포). dev 브랜치 신경 안 써도 됨.

---

## 2. 💰 절약 블로그 (retwork.jp/blog)

### 민우가 줄 것
- 글 주제 (예: "겨울 난방비 절약법")
- 핵심 포인트 몇 개 (또는 주제만 줘도 초안 작성 가능)
- 타겟 독자 (예: 자취생 / 주부 / 학생)

### Claude가 만드는 것
`public/blog/<슬러그>.html` 파일, SEO 태그 **전부** 포함:
- `<title>`, `<meta name="description">`, `<meta name="keywords">`
- `<link rel="canonical">`
- OG 태그 (og:type/title/description/url/locale)
- `<script type="application/ld+json">` (구조화 데이터)
- 기존 기사(`setsuyaku-7tips.html` 등)와 동일한 디자인/구조

그리고 **`public/sitemap.xml`에 새 기사 URL 추가** (절대 빠뜨리면 안 됨):
```xml
<url>
  <loc>https://retwork.jp/blog/<슬러그>.html</loc>
  <lastmod>YYYY-MM-DD</lastmod>
  <changefreq>monthly</changefreq>
  <priority>0.8</priority>
</url>
```

### 배포
- 절약 블로그는 RetWork 메인 레포라 **`main` 브랜치**에 가야 retwork.jp에 반영됨
- dev에서 작성 → main으로 반영 (사이트맵 SEO 수정처럼 cherry-pick 하거나 merge)
- 또는 글 작업은 main에서 직접 (테스터 앱 코드와 무관한 블로그 파일이라 안전)

---

## 3. 글 올린 뒤 (둘 다 공통) — Google Search Console

새 기사 배포 후, 구글이 빨리 알게 하려면:
1. **GSC → URL 검사** → 새 기사 전체 주소 입력 → **색인 생성 요청**
2. (절약 블로그) 사이트맵 바뀌었으니 **Sitemaps → 다시 제출**
3. 보통 2~7일 내 색인됨

---

## 4. 요청 예시 (민우가 이렇게만 말하면 됨)

> "그루메 글 쓰자. 神保町 '저고리' 한국집, 점심 3명 ¥3,300, 두유냉면+치킨정식, 평가는 기대보단 별로. 사진 첨부함."

> "절약 글 쓰자. 주제: 자취생 통신비 줄이는 법. 격안 SIM 추천 위주로. 타겟은 20대 자취생."

→ Claude가 SEO 완비된 완성본 만들어서 → 확인 → 배포.

---

## 5. SEO 체크리스트 (Claude가 매번 확인)

- [ ] title (검색 제목, 60자 내외, 키워드 포함)
- [ ] description (검색 설명, 120자 내외, 클릭 유도)
- [ ] canonical (정확한 최종 주소)
- [ ] OG 태그 (SNS 공유 시 미리보기)
- [ ] 구조화 데이터 (ld+json, Article)
- [ ] 사이트맵 등록 (절약=수동 / 그루메=자동)
- [ ] 이미지 alt 텍스트
- [ ] 내부 링크 (앱/다른 기사로)
