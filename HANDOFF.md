# RetWork (チリつも) — HANDOFF (build 430 + SNS 자동화 시점)

> 다른 컴퓨터에서 이어서 작업할 때 이 파일부터 읽으면 현황 파악 완료.
> 최신 빌드: **build 430** · 도메인: **retwork.jp** · 일본 시장 타겟 영수증 OCR + 가성비 가게 정보 공유 PWA.
> 블로그(SEO/AdSense): **blog.retwork.jp** (별도 레포 `SMW-Code/retwork-blog`)
> 마지막 작업: **2026-06-10** (블로그 X+Threads 자동 게시 / 이미지 편집 / 어드민 가게사진 통합)

---

## 0-B. 2026-06-10 세션 변경 요약 — SNS 자동화 + 어드민 가게사진

### 메인 앱 (receiptiq)

| build | 내용 |
|---|---|
| **429** | 어드민 가게수정 화면의 가게사진이 안 보이는 버그 안전망 (`onerror` fallback / 사진 클릭 시 새 탭 원본 / console 진단 로그) + 정렬을 「대표 → 최신 등록순」 으로 단순화 + 수동 ↑↓ 정렬 폐지 |
| **430** | 어드민 가게사진을 **`store_photos`(어드민 등록) + `store_community_photos`(유저 등록) 통합 조회**. 각 사진에 「관리자/유저」 출처 라벨. 유저 사진을 대표로 지정하면 `store_photos` 에 자동 복사 후 `is_primary=true` (원본은 양쪽에 그대로). 삭제는 각 출처 테이블 + Storage 파일 모두 |

`_admLoadStorePhotos / _admTogglePrimaryPhoto / _admDeleteStorePhoto` 가 `source` 인자(`'admin'` | `'community'`) 받음.

### 블로그 (retwork-blog) — **`SMW-Code/retwork-blog` 별도 레포**

1. **X (트위터) 자동 게시** — `/api/sns/x/route.ts` 신설, `twitter-api-v2` 패키지
   - 발급 후 Vercel 환경변수 4개 등록: `X_API_KEY` / `X_API_SECRET` / `X_ACCESS_TOKEN` / `X_ACCESS_TOKEN_SECRET`
   - 280자 자동 메시지 + 「메시지 직접 작성하기」 옵션
   - **트위터 자체 무료 plan 폐지**됨 → pay-per-use 크레딧 필요 (월 1500건은 충분)
   - App permissions 「Read and write」 필수 (Read-only 면 403)
   - 수정 모드에선 기본 OFF (같은 트윗 중복 시 403 Duplicate)
2. **Threads 자동 게시** — `/api/sns/threads/route.ts` 신설
   - `THREADS_USER_ID` / `THREADS_ACCESS_TOKEN` 2개 환경변수
   - Meta Developer 앱 → 「Threads API 액세스」 use case → Threads 테스터 추가 → Long-lived token 발급
   - 2단계 게시 (컨테이너 생성 → publish), 500자, URL 단축 없음
3. **공통 모듈** `lib/sns.ts` — `formatTweet` / `formatThread` / `postToX` / `postToThreads` + 결과 타입. 기존 `/api/sns/x`, `/api/sns/threads` 도 이걸 사용하도록 리팩토링
4. **기존 글 재공유 endpoint** `/api/sns/share-by-slug/route.ts`
   - 입력: `{ password, slug, platforms?: ['x','threads'], customX?, customThreads? }`
   - 인증: `ADMIN_PASSWORD` **또는** `BLOG_PUBLISH_KEY` (별도 게시키, 옵션)
   - 글 목록 UI 에 `[X] [Threads] [X + Threads]` 3 버튼 추가 (이모지에서 텍스트로 교체)
   - curl 한 줄로 외부 자동화 가능
5. **이미지 회전·자르기** — Canvas 기반 모달
   - 대표 이미지 / 이미지 블록 둘 다에 「✂️ 회전·자르기」 버튼
   - 회전: 좌 90° / 우 90° / 180° / 초기화
   - 비율: 원본 / 1:1 / 4:3 / 16:9 / 3:2 / 3:4 / 9:16 (중앙 자동 자르기)
   - 적용 시 Canvas.toBlob → JPEG q0.9 → 새 File
6. **이미지 자동 압축** (가장 중요한 픽스) — `compressImage(file, 1600, 0.85)`
   - 「Request Entity Too Large (413)」 → 클라가 받은 HTML 을 `.json()` 으로 파싱하다 `"Unexpected token 'R', \"Request En\"..."` 에러 발생
   - 원인: base64 인코딩 시 1.33배 → Vercel API Route 4.5MB 한계 초과
   - 픽스: 파일 선택 직후 1600px / JPEG 85% 로 자동 변환 → 5MB → 200~500KB
   - `pickHero` / `setBlockFile` async 화
7. **6편째 블로그 글**: `nagi-niboshi-jimbocho.md` (神保町 すごい煮干ラーメン凪 정직 후기 ★★★☆☆+)

관련 commit (retwork-blog):
- `45e1206` 이미지 회전/자르기
- `d2dd3fe` 이미지 자동 압축
- `15dcdac` SNS 버튼 이모지→텍스트
- `5d7a6ac` nagi 블로그 글
- `7a6862b` X 자동 게시 신설
- `862609e` Threads 자동 게시
- `ad16d39` share-by-slug + 글목록 SNS 버튼 + BLOG_PUBLISH_KEY 인증

## 0-A. 이번 세션(2026-06-09) 변경 요약 — 인프라/콘텐츠

코드 빌드(428)는 다른 PC 에서 작업되었고, 이 PC 에서는 **운영자 정보 / 도메인 메일 / DNS** 정리 작업 진행:

| 영역 | 변경 |
|---|---|
| 도메인 DNS | Onamae → **Cloudflare** 로 네임서버 이전 (`bart/fiona.ns.cloudflare.com`) |
| Vercel 레코드 | A `retwork.jp` / CNAME `blog`, `www` **모두 프록시 OFF** (회색 구름) — Vercel과 Cloudflare 프록시 같이 켜면 충돌 |
| 도메인 메일 | **Cloudflare Email Routing** 활성화 → `info@retwork.jp` → 본인 Gmail 로 포워딩 |
| Gmail 발신 | "다른 주소로 메일 보내기" 등록 (SMTP `smtp.gmail.com:587` + Google **앱 비밀번호**) — 답장도 `info@retwork.jp` 발신 가능 |
| 운영자 익명화 | `SEO MINWOO` → `RetWork 編集部` (15개 파일 / 36개 위치) — `about/contact/privacy/terms/index` + blog 11편 |
| 연락처 익명화 | `minwoo.seo1019@gmail.com` → `info@retwork.jp` 전부 |
| 모킹 페이지 | `민/민우님` → `ゲ/ゲストユーザー` (prototype, home-mockup, design-compare) + 한국어 한 줄 → 일본어 |
| robots.txt | `/prototype.html`, `/home-mockup.html`, `/design-compare.html`, `/design-preview.html`, `/color-preview.html`, `/report-mock.html` 색인 차단 |
| ads.txt | 이미 정상 (`google.com, pub-6495876616577319, DIRECT, f08c47fec0942fa0`) — AdSense 인식 대기(24~48h) |

관련 커밋:
- `e4ec3bb` — 운영자/이메일 일괄 교체 (15개 / 36 위치)
- `d407275` — 모킹 페이지 익명화 + robots.txt 차단

---

## 0. 프로젝트 한눈에

- **단일 파일 PWA**: `public/index.html` (~25,000 lines) + `public/sw.js`
- **API routes**: `app/api/{vision,gpt,push,cron,resolve-gmap}/route.ts` (Next.js 16 App Router, Node runtime)
- **백엔드**: Supabase (Postgres + Auth + Storage + Realtime)
- **배포**: Vercel 자동 (`main` push → 즉시 반영)
  - **메인 앱**: 프로젝트명 `ret-work`, Root Directory = repo root, 도메인 retwork.jp
  - **블로그**: 프로젝트명 `retwork-blog`, Root Directory = `blog`, 도메인 blog.retwork.jp
- **모드**: ReceiptIQ (가계부) ↔ チリつも (가성비 맵)
- **i18n**: 4언어 (ja / ko / en / zh) — `data-i18n` 속성 + `I18N` 객체 + CMS

### ⚠️ Vercel 빌드 함정 (한 번 데였음)

저장소 root 의 `tsconfig.json` 은 **반드시 `"exclude": ["node_modules", "blog"]`** 유지.
이유: 메인 앱 (`ret-work`) Vercel 빌드가 `blog/*.ts` 까지 type check 하면서
`gray-matter` 등 blog 의존성을 못 찾아 빌드 실패. b384~b388 + 모든 블로그 커밋이
**8시간 동안 prod 배포 못 됨**의 진짜 원인이었음 (commit a639f3f 로 픽스).

블로그 폴더에 새 ts/tsx 파일을 추가해도 메인 빌드가 안 깨지는지 항상 Vercel 대시보드에서 한 번 확인할 것.

---

## 1. 빌드 / 캐시

```
public/index.html → window.__APP_BUILD__ = 404;
public/sw.js      → CACHE_NAME = 'receiptiq-v0.9.0-b404';
```

### build 404 — 어드민 모바일도 PC 타입(반응형)으로 통일
- `openAdminDashboard`: 너비 768px 분기 제거 → **모바일·PC 모두 `openAdminPc()`**. 모바일 시트(ov-admin)는 미사용.
- 반응형 CSS(≤767px): 톱바 탭 `#apc-tabbar` 가로스크롤, 본문 `#apc-body` 세로스택, 사이드바 `#apc-sidebar`를
  240px 세로 → **상단 가로 스크롤 띠**(칩 형태 `.apc-menu-item`), 섹션헤더 숨김, 이메일 숨김, 패딩 축소.
- 마크업 id 추가: apc-topbar/apc-logo/apc-tabbar/apc-body. `_isAdminPcActive`는 ov-admin-pc 표시여부만 봐서 자동 호환.

### build 403 — 광고 시청 게이트 버튼 문구 컨텍스트별로
- `watch-ad-primary-btn` 라벨이 항상 "광고 보고 내용 확인하기"였던 것 → 컨텍스트 `base.descTitle` 사용(16003).
  치리 공개=「광고 보고 치리에 공개하기」, 저장=「…가계부에 무료 저장」 등 자동.

### build 402 — 어드민 가격핀 코멘트 전용 삭제
- 가격핀 카드에 **"💬 삭제"**(코멘트만, 핀/마커 유지 = `_admPcClearPinComment` UPDATE comment='') 추가. 기존 "삭제"→"핀 삭제"로 명확화.
- 미해결(분석 중): 새로고침 시 마지막 화면 복원 안 됨(_restoreNav/_loadSavedNav sessionStorage 로직), 전체화면 모달에서 PTR 비활성(25918 `.bottom-sheet-overlay` disarm).

### build 401 — 어드민 가격핀 닉네임 + 댓글삭제 RLS 무효 감지
- 어드민 가게핀 상세(`_admPcOpenPinStoreView`): 가격핀 카드의 `UID:xxx` → **작성자 닉네임**(profiles 조회 `_pinNick`). 메뉴이름/가격은 유지.
- `_admPcDeleteComment`: `.delete().select()`로 실제 삭제행 확인 → **0건이면 RLS 막힘 경고**(조용한 no-op 방지).
- ★ 가게코멘트 삭제가 유저페이지에 반영 안 되던 원인 = `store_comments_admin_delete` RLS 미적용 추정 →
  **Supabase에 `admin_rls_policies.sql` 실행 필요**. (또는 price_pins.comment 복사본은 build 400 이전 데이터에 잔존)

### build 400 — 가격핀 코멘트를 가게코멘트→메뉴별 코멘트로
- `submitChiriPublish` newPins의 `comment`를 공통 `commentText`(가게 코멘트) → **그 메뉴의 코멘트 `item.cpComment`** 로 변경.
  어드민 가격핀에 모든 핀이 같은 가게코멘트로 복제되던 문제 해결(메뉴 이름↔코멘트 일치). 가게 코멘트는 store_comments에만.

### build 399 — 치리 공개 코멘트 문구 명확화
- 메뉴 코멘트 placeholder: "このメニューについてコメントを書いてください". 가게 코멘트: 라벨 "💬 お店についてのコメント" 추가 + placeholder "お店全体について…". (어느 대상 코멘트인지 직관적으로)

### build 398 — 치리 공개: 메뉴별 코멘트 추가
- 품목 프리뷰 각 행에 코멘트 input(`cpSetItemComment`→`it.cpComment`, 재렌더 안 함). `submitChiriPublish`에서
  `store_menu_comments.content=_mC`(평점 없어도 코멘트만 있으면 insert, rating은 null 허용). 메뉴별 코멘트도 차단어 검사.
- 하단 cp-comment(가게 단위 코멘트)는 그대로 store_comments에 저장(별개). ⚠️ store_menu_comments.rating NOT NULL이면 코멘트-only insert 실패 가능(catch됨) → 필요시 컬럼 nullable로.

### build 397 — 치리 공개 모달 개편: 가게사진 + 메뉴별 평점/사진
- `ov-chiri-publish`: 가게명 아래 **가게 사진 첨부**(`cp-store-photo`/`cpPickStorePhoto`→`store_community_photos`).
- 전역 별점 1개 제거 → **품목 프리뷰(`updateCpPreview`)에서 메뉴별 별점**(`cpSetItemRating`, `it.cpRating`) + **메뉴별 사진**(`cpPickItemPhoto`, `it.cpPhotoFile`).
- 사진 첨부 공통: 숨은 input `cp-photo-input`+`cpOnPhotoPicked`, 업로드 헬퍼 `_cpUploadPhoto(file,subdir)`(압축→store-photos 버킷→publicUrl).
- `submitChiriPublish`(async): 가게사진 업로드 → store_comments(평점=메뉴별 평균) → 품목별 루프(사진 업로드+신규/기존 카드 분기, 기존카드 image_url 비면 채우고 아니면 store_menu_photos에 추가, 평점은 store_menu_comments). 중복제출 가드 `_cpSubmitting`+버튼 비활성화.
- DB 변경 없음(store_community_photos/store_menu_photos 기존 테이블 사용). dead code: cpSelectStar/_cpStarRating(미사용).

### build 396 — 설정창 글자 크기(앱 UI 스케일) 기능
- 설정창에 文字サイズ(小/標準/大/特大) 컨트롤(`#font-scale-opts`). `applyFontScale(scale)` → `#app`에 `zoom` 적용.
- 핵심: 인라인 px 폰트라 rem 불가 → **zoom 방식**. `.phone` 높이/폭은 `_syncPhoneVH`에서 **÷scale 보정**(window._fontScale)
  → 전체높이 안 깨짐. localStorage `riq_font_scale`, 시작 시 복원. 기본 1(標準)에선 변화 없음(zero-risk).
- i18n `settings.fontsize` 4언어. ⚠️ 지도(Google Maps)는 zoom 영향권 — 큰 스케일에서 마커 클릭 오프셋 가능(실기기 확인).

### build 395 — 메뉴카드 추가 폼 이모지→SVG
- 가게상세 메뉴카드 추가(`sdOpenAddCard`/`_sdRenderCatPicker`): 대분류 칩(🍣일식…), 🏷️/🍽️/📷 이모지를 SVG 라인 아이콘으로.
- 대분류는 `_SD_CAT1_ICON`(키→ct아이콘키) 매핑 + `_ctCatSvgStr` 사용. **저장값(SD_CATS 키, 이모지 포함)은 그대로** 유지(기존 카드 안 깨짐), 표시만 SVG+라벨(선두 이모지 strip).
- 참고: 저장된 메뉴 카드의 카테고리 문자열엔 여전히 이모지 포함(표시 위치별로 추후 strip 가능).

### build 394 — 어드민 영수증 카테고리 select 이모지 제거(+군것질 추가)
- `adm-rec-cat` select 옵션의 선두 이모지 제거(텍스트만 — `<option>`은 SVG 불가). snack 옵션 추가.
- 참고: 치리톡 음식 카테고리 칩은 이미 `_paintCtCatChips()`(applyLang에서 호출)가 런타임에 SVG로 변환 중이라 변경 불필요. 지도 마커는 의도적으로 이모지 유지.

### build 393 — 수동입력 모달 카테고리 칩 이모지→SVG 라인 아이콘 통일
- 지출 카테고리 시스템 UI를 전부 단색 SVG로 통일(`CAT_ICON`). 수동입력 모달만 이모지였던 것 수정.
- 남은 이모지(미변경): 치리톡 음식 카테고리 칩(ct.cat, 별도 시스템), 어드민 select(`<option>` SVG 불가),
  지도 마커 핀(CAT_EMOJI/CT_CAT_EMOJI, data-URI). 필요 시 후속 작업.

### build 392 — OCR 결과에 지출방법 파싱·선택 + 카테고리 군것질 추가/외식→식사
- **지출방법**: GPT 프롬프트에 `pay`(credit/debit/ic/qr/cash) 판정 규칙+출력필드 추가. `parseWithGPTMulti` 등
  result 빌더 3곳에 `pay:_normPay(result.pay)`. OCR 결과화면(`showOcrResult`)에 지출방법 선택기(`ocr-pay-select`,
  `selectOcrPay`) 추가 — GPT값 pre-select, 사용자 수정 가능. 저장 시 `payment_method:r.pay`(기존 null 하드코딩 수정).
- **카테고리 snack(군것질·과자)** 신규: `_CAT_ICON_PATHS`(cookie)/`CAT_EMOJI`(🍪)/`_CAT_LABEL_KEYS`/i18n 4언어
  (`cat.snack`) + OCR allCats + 수정/수동 모달 cats 배열에 추가.
- **외식→식사**: `cat.eat` 값 변경 (ja 食事/ko 식사/en Meal/zh 用餐). 키는 'eat' 그대로(집계 로직 안 깨짐).

> ⚠️ 어드민 가격핀→어드민 편집 회귀수정(구 build 391)은 `backup-b391-395` 브랜치에 보관됨. 추후 재적용 예정.

### build 391 — 영수증 수정 품목 행 레이아웃 수정
- 영수증모드 > 내역 > 지출카드 > 수정 시 품목 행이 가로 넘쳐 X(삭제)버튼이 잘리던 문제.
- `renderEditItems()` (index.html ~7682): 가격칸 `flex:1`→**고정 76px**(우측정렬), 이름칸 `flex:1+min-width:0`,
  수량칸 40px, 전 입력칸 `box-sizing:border-box` → 한 화면에 다 들어오고 X 항상 표시.

### build 390 — 가게목록 펼침 영역 좌측 쏠림 수정
- `.shop-card`가 `align-items:flex-start`라 펼침 detail이 내용폭만 차지 → 좌측 쏠림.
- `#{sId}-detail` 에 `width:100%;box-sizing:border-box;` 추가 → 카드 전체폭 사용.

### build 389 — 위치수정 요청 (가게목록 직접편집 → 요청 모델) ★ SQL 실행 필요
**`store_edit_requests_kind.sql` 실행 필요** (store_edit_requests 에 `kind` 컬럼 추가).
- 가성비맵 가게목록: 직접 위치수정(`startManualPin`) 버튼 **삭제**. 카드 펼침 영역에 **📍 位置修正をリクエスト** 버튼 추가.
  no-pin 가게도 펼쳐지게 `toggleStoreCard()` 추가(지도이동 없이 토글), chevron 항상 표시.
- 요청 모달은 기존 `ov-store-edit-req` **재사용** — `window._serReq={kind,store_name,lat,lng}` 컨텍스트로
  일반(`sdReqEdit`) / 위치(`reqStoreLocationEdit`) 분기. `submitStoreEditReq()`가 kind 포함 insert
  (kind 컬럼 없으면 자동 재시도로 graceful).
- 어드민: 기존 "가게 수정요청" 옆에 **"📍 위치수정 요청"** 카드 추가. 같은 모달 `ov-admin-edit-reqs`를
  `_setEditReqKind(kind)`로 제목/필터 전환(kind는 **클라에서 필터** → 컬럼 없어도 안 깨짐).
  배지 2개(`adm-editreq-badge`/`adm-locreq-badge`), PC드릴다운 `editreqs`/`locreqs` 항목.

**캐시 정책**: HTML 은 네트워크 우선 (`no-store`), 나머지 정적 자원은 캐시 우선. 사용자에게는 항상 `Ctrl+Shift+R` 강제 새로고침 안내. PWA 설치된 경우 앱 종료 후 재시작.

### build 388 — Google 지도 단축 링크 자동 좌표 추출
- 새 API: `app/api/resolve-gmap/route.ts` (Node runtime)
  - `maps.app.goo.gl` / `goo.gl` 단축 URL → server-side fetch (redirect:'follow') → 최종 URL 의 좌표 추출
  - SSRF 방지: Google 도메인 화이트리스트
  - 모바일 UA 헤더로 정확한 redirect 유도
- 클라이언트 `_admGmapUrlChanged(url)` (in `index.html` ~23710):
  - 정식 링크 → 즉시 정규식 추출 (`@lat,lng` / `!3d!4d` / `?q=` / `?ll=`)
  - 단축 링크 → `/api/resolve-gmap?url=...` 호출 → 좌표 받아 동기화
  - `_admApplyExtractedLatLng()` 헬퍼로 lat/lng input + 마커 + 지도 panTo + 토스트
  - 중복 호출 차단: `_admGmapLastExtractedKey`, `_admGmapShortResolvedFor`

### build 387 — 정식 Gmap URL 자동 좌표 추출 (b388 의 1단계)
- 가게 편집 UI 의 `adm-store-gmap` input 에 `oninput` 핸들러 추가
- `_admExtractLatLngFromGmapUrl()` 정규식 함수
- `openAdminStoreDetail()` 진입 시 캐시 키 reset

### build 386 — 가게 그룹 카드 onclick 안전 escape
- `index.html` 라인 ~13172 의 `_toggleStoreItems` / `flyToStoreFromHistory` 호출
- `_attrArgs(...)` 헬퍼: `JSON.stringify` → `.replace(/"/g,'&quot;')` 통일
- b384 와 같은 종류 잠재 위험 일괄 정리

### build 385 — 메뉴 사진 출처 시트 z-index
- `#ov-store-detail` (z-index:980) 가 stacking context 형성 → `#ov-photo-source` (기본 .overlay 500) 가 뒤로 깔리던 버그
- CSS: `#ov-photo-source{z-index:1100;}` (라인 628 근처)
- JS: `sdStartCardPhoto` 의 `openOv` 직전에 `document.body.appendChild(ps)` 트릭 (다른 모달 패턴과 통일)

### build 384 — 영수증 내역 마ップで見る 버튼 SyntaxError
- 라인 7373: `onclick="...flyToStoreFromHistory("X","Y",...)"` 에서 JSON.stringify 결과의 `"` 가 attribute 종료 따옴표와 충돌
- 인자들을 `JSON.stringify().join(',').replace(/"/g, '&quot;')` 로 처리

### build 383 — 사진 업로드 자동 압축 + 메뉴 카드 사진 prefetch
- `_compressImage(file, maxDim, quality)` 헬퍼 (Canvas 기반)
- 메뉴 카드/가게 사진 업로드 시 자동 압축

### build 382 — 출석 토글 localStorage 캐싱
- `att_push_optin`, `att_push_row_visible` — 설정창 진입 시 깜빡임 제거

### build 380-381 — 코스파맵 주변 미방문 가게 마커
- `_ctShowUnvisitedMarkers` — 현재 위치 기준 반경 내 가게 중 사용자 미방문 가게를 별도 색 마커로 표시

### build 379 — 가게 상세 모달 전체창 전환 (이전 핸드오프 시점)
- 바텀시트(92vh) → 전체창. CSS `#store-detail-panel`: border-radius:0, height/max-height:100%
- `#sd-header` 상단 sticky + safe-area-inset-top, 좌측 ‹ 뒤로가기 버튼

---

## 2. Supabase 스키마 (현재 적용된 핵심 테이블)

| 테이블 | 핵심 컬럼 | 용도 |
|---|---|---|
| `profiles` | id, nickname, is_admin, budget_amount, budget_month, deleted_at | 사용자 |
| `receipts` | id, user_id, store_name, receipt_date, total_amount, lat, lng, store_address | 영수증 |
| `items` | id, receipt_id (FK CASCADE), name, quantity, price, category, product_id | 영수증 품목 |
| `stores` | id, name, lat, lng, category, avg_price, receipt_count, google_maps_url, featured_price, featured_menu_name | 가게 |
| `price_pins` | id, store_id, item_name, price, comment, user_id | 가성비 핀 (치리 공개) |
| `store_menu_cards` | id, store_name, menu_name, price, category, image_url, is_featured, rating_avg, rating_count, sort_order | 메뉴 카드 |
| `store_menu_photos` | id, menu_card_id (FK CASCADE), image_url, is_primary, sort_order, uploaded_by | 메뉴 추가 사진 |
| `store_menu_comments` | id, menu_card_id (FK), user_id, rating, content, updated_at — UNIQUE(menu_card_id, user_id) | 메뉴별 평점/댓글 |
| `store_menu_replies` | id, comment_id (FK), user_id, content | 메뉴 댓글 답글 |
| `store_comments` | id, store_name, user_id, user_name, content, rating, has_receipt | 가게 단위 방문자 리뷰 |
| `store_photos` | id, store_name, photo_url, user_id, is_primary, sort_order | 가게 사진 (어드민) |
| `store_community_photos` | id, store_name, photo_url, uploaded_by | 가게 사진 (유저 등록) |
| `announcements` / `store_items` / `comment_reports` / `banned_words` / `banned_users` | — | 공지/스토어/신고/제재 |
| `coin_transactions` / `ad_views` | — | 보상/광고 |
| `products_master` | id, name, normalized_name, ... | GPT 정규화 상품 |
| `store_edit_requests` | — | 가게 수정 요청 (사용자) |
| `private_notes` | — | 가게별 비공개 메모 |
| `i18n_translations` | key, ja, ko, en, zh | i18n CMS |
| `web_push_subscriptions` | id, user_id, endpoint, p256dh, auth | Web Push 구독 |
| `admin_messages` | id, recipient_id, title, content, ... | 어드민 → 유저 쪽지 |

### 적용한 SQL 파일들 (`./*.sql`)

- `store_photos.sql` — 사진 관련 테이블 (idempotent v3, store_name 기반)
- `admin_rls_policies.sql` — 어드민 INSERT/UPDATE/DELETE + 본인 정책
- `merge_duplicate_menu_cards.sql` — 메뉴 카드 통합 사례 (참조용, 1회성)
- `dedupe_menu_comments.sql` — 댓글 content 중복 정리 (참조용)
- `profiles_budget.sql` — 예산 컬럼 추가

### Supabase Storage Bucket

| Bucket | Public | 용도 |
|---|---|---|
| `store-photos` | ✅ | 가게 / 메뉴 / 커뮤니티 사진 (5MB, image/*) |
| `receipts` (기존) | ✅ | 영수증 이미지 |

Storage 정책: SELECT 누구나, INSERT/UPDATE/DELETE 는 본인 또는 어드민.

---

## 3. 블로그 (blog.retwork.jp) — AdSense 통과용

- 위치: `blog/` 폴더 (별도 Next.js 15 + Markdown + gray-matter)
- 폴더 구조:
  - `blog/app/{layout,page,about,privacy,terms}/page.tsx` (인라인 CSS via `dangerouslySetInnerHTML`)
  - `blog/app/posts/[slug]/page.tsx` (`generateStaticParams` + force-static)
  - `blog/app/{robots.txt,sitemap.xml}/route.ts`
  - `blog/lib/posts.ts` (gray-matter + remark)
  - `blog/posts/*.md` — frontmatter (title/date/description/image/tags/author)
  - `blog/public/images/<slug>/*.jpg` — 사진 (자동 압축됨)
  - `blog/scripts/compress-images.js` — sharp 기반 일괄 압축 (1600px, q78, mozjpeg)

### 운영 흐름

```bash
# 새 글 작성
cd blog
# 1. blog/posts/<slug>.md 작성 (frontmatter + 본문)
# 2. blog/public/images/<slug>/ 폴더에 사진 저장
# 3. 압축
node scripts/compress-images.js public/images/<slug>
# 4. push (Vercel 자동 배포)
git add blog/posts/<slug>.md blog/public/images/<slug>/
git commit -m "blog: add <slug>"
git push
```

### 현재 글 목록 (5편 / AdSense 권장선 도달)

| # | slug | 카테고리 |
|---|---|---|
| 1 | `kitakata-shokudo-jimbocho` | 음식점 후기 |
| 2 | `chogori-jimbocho` | 음식점 후기 |
| 3 | `retwork-app-guide` | 앱 가이드 |
| 4 | `how-to-keep-kakeibo` | 라이프해크 |
| 5 | `analyze-food-habits-from-receipts` | 데이터 분석 |

### 인프라

- Search Console: 소유권 인증 OK (`blog/public/google4a48c85cc102d622.html`)
- Sitemap 제출 완료
- DNS: 오나마에닷컴 CNAME `blog → cname.vercel-dns.com`
- AdSense: 미신청 (5편 + 며칠 색인 안정화 대기)
- 환경변수: `NEXT_PUBLIC_ADSENSE_CLIENT` 비어 있음 (AdSense 승인 후 설정)

---

## 4. SVG 아이콘 시스템 (`window.__LICO_SET__`)

라인 ~24825. 50+ Lucide-style stroke SVG. 사용:

```js
icon('camera', 26, 'var(--green)')  // 인라인 SVG 문자열 반환
```

또는 마크업으로:
```html
<span class="lico" data-lico="camera" data-size="20" data-color="var(--text-2)"></span>
```

`_renderLicos()` + MutationObserver 가 자동 변환.

---

## 5. 주요 흐름

### 영수증 OCR → 저장
1. 카메라/이미지 선택 → `/api/vision` (Node runtime, GPT Vision)
2. `result.date` 는 **원본 표기** ("26年6月4日", "平成26年6月4日") — build 346 부터 GPT 환산 X
3. 클라이언트 `_sanitizeReceiptDate` 가 5가지 패턴 처리 (元号/2자리/4자리/ISO)
4. OCR 결과 화면에 가게명/날짜(input type=date)/카테고리/품목/총액 편집
5. 저장 흐름:
   - **가계부에 저장하기** → `_doSaveOcrResult()` (광고 → receipts insert)
   - **가계부 저장 ＆ 치리츠모 공개** → `_doSaveOcrResult()` (즉시) + `openChiriPublish()` 모달 → `submitChiriPublish()` (price_pins insert + store_menu_cards 중복 방지)

### 가게 상세 모달 (`ov-store-detail`) — z-index 980, 전체창
- 헤더 → 사진(H=244px) + 사이드 4 버튼 → Google 정보 → 광고 → 메뉴 카드 → 방문자 리뷰 → 비공개 메모
- 사이드 4 버튼: 📷(camera) / 🗺️(map_pin) / 🌐(globe) / 📤(share)
- 점점점 메뉴: 수정 요청 / 닫기
- 이 모달이 stacking context 형성 → 그 위에 띄울 모달은 z-index 1000+ + body 마운트 트릭 필요

### 어드민 가게 편집 모달
- 위치: `ov-admin-edit-store`
- 필드: 이름 / 카테고리 / lat / lng / google_maps_url / 미니맵 (drag 가능한 마커)
- **google_maps_url 입력 → 좌표 자동 추출** (b388):
  - 정식 링크: 즉시 정규식
  - 단축 링크: `/api/resolve-gmap` 서버 fetch
  - 마커 + lat/lng input 동시 갱신

### 사진 슬라이드 + 전체화면 뷰어
- 가게 사진: `store_photos` + `store_community_photos` 통합, 대표 우선
- 메뉴 카드 사진: `store_menu_cards.image_url` + `store_menu_photos`
- 뷰어: `ov-sd-photo-viewer` (z-index 99999, body 마운트), ‹/›/✕/Esc + 키보드

### 어드민 PC 모드
- `_admPcDrilldownTo(modalId, opts)` → 시트를 콘텐츠 영역에 마운트
- 가게 편집 모달 / 메뉴 카드 수정 / 가게핀 페이지 등

---

## 6. Web Push (build 306~)

- VAPID 키: Vercel 환경변수 `VAPID_PUBLIC_KEY` / `VAPID_PRIVATE_KEY`
- 구독: `/api/push/subscribe`
- 발송: `/api/push` (cron + 운영팀 메시지)
- GitHub Actions cron — `.github/workflows/attendance-push.yml` (출석 슬롯 8:00/16:00 JST)
- TWA APK: PWA Builder, package=`jp.retwork.app`, SHA-256 등록 (`/public/.well-known/assetlinks.json`)

---

## 7. 최근 build 흐름 (379~388)

| build | 내용 |
|---|---|
| **379** | 가게 상세 모달 전체창 전환 |
| **380-381** | 코스파맵 주변 미방문 가게 마커 |
| **382** | 출석 토글 localStorage 캐싱 (깜빡임 제거) |
| **383** | 사진 업로드 자동 압축 + 메뉴 카드 사진 prefetch |
| **384** | 영수증 내역 マップで見る onclick SyntaxError 픽스 |
| **385** | 메뉴 사진 출처 시트 z-index/body 마운트 |
| **386** | 가게 그룹 카드 onclick 안전 escape (재발 방지) |
| **387** | 어드민 Gmap URL → 정식 링크 좌표 자동 추출 |
| **388** | 어드민 Gmap URL → 단축 링크도 자동 추출 (`/api/resolve-gmap`) |
| (commit) | `a639f3f` — tsconfig 에 blog exclude — Vercel 빌드 정상화 |

---

## 8. 다음 작업 후보

### 앱
- 어드민 가게 편집: 단축 링크 자동 추출 검증 + 좌표 추출 실패 시 fallback UX 개선
- 메뉴 카드 순서 배열 — 어드민 드래그/↑↓로 sort_order 설정
- 다국어 미적용 라벨 발견 시 i18n CMS (`openAdminI18n`)
- 가게 상세 모달 디자인 미세 조정

### 블로그
- 6편째 글 후보:
  - C. 神保町 가성비 음식점 큐레이션 (지금 2곳 + 街ガイド)
  - G. 「節約レシピ・買い物リスト術」 일반론
  - I. PWA 가계부 vs 네이티브 앱 비교
  - 직접 다른 가게 영수증/사진 받으면 후기 추가
- 며칠 색인 안정화 후 AdSense 신청
- AdSense 승인되면 `NEXT_PUBLIC_ADSENSE_CLIENT` 환경변수 설정

---

## 9. 환경 / 명령

### 로컬 개발
```bash
cd C:\Users\minus\Desktop\receiptiq
npm run dev               # 메인 앱 (Next.js 16, port 3000)

# 블로그
cd blog
npm run dev               # 블로그 (Next.js 15, port 3001)
```

### 배포
```bash
git push                  # main 푸시 → Vercel 두 프로젝트 모두 자동 배포
```

### Supabase
- 프로젝트: `fkvfbxfgidrvymoftkdd.supabase.co`
- SQL Editor 에서 `./*.sql` 파일 실행
- Storage Dashboard 에서 `store-photos` bucket 관리

### Vercel
- 메인 앱: https://vercel.com → `ret-work` 프로젝트
- 블로그: https://vercel.com → `retwork-blog` 프로젝트
- **항상 push 후 1-2분 안에 Vercel Deployments 에서 Ready 인지 확인** (b384~b386 8시간 빌드 실패 사건 재발 방지)

---

## 10. 자주 쓰는 디버깅 console 로그

```
[chiri-publish] 가계부 저장 시작 (광고 모달 전)
[chiri-publish] menu_cards: new=N, existing=N
[admLoadStoreMenus] 정확 매칭 / fuzzy 후보 / 최종 표시
[admPcEditMenuCard] 정확 매칭 / fuzzy 매칭 성공
[admLoadMenuPhotos] legacy=... | siblings=...
[admPcLoadStoreMenuCards] storeName → N개
[admPcDeletePin] 삭제된 행 수
[sdSubmitComment] store_comments 동기화 시도
[sdSubmitComment] store_comments updated: N
[receipt date] 5+ years past — 확인 필요
[resolve-gmap] (b388) 단축 링크 해석 실패/성공
```

---

## 11. RLS / 보안 패턴

- `auth.uid()` 기반 본인 정책
- 어드민: `EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE)`
- 모든 INSERT/UPDATE/DELETE 코드에 `.select()` + length 검증 추가 (RLS 차단 시 사용자에게 명시적 알림)
- 새 테이블 추가 시 `admin_rls_policies.sql` 에 정책 추가하는 패턴
- 새 서버 API route 추가 시 SSRF/도메인 화이트리스트 (예: `app/api/resolve-gmap` 의 ALLOWED_HOSTS)

---

## 12. 데이터 정리 유틸 SQL (수동 1회성)

- `./merge_duplicate_menu_cards.sql` — 메뉴 카드 통합 (특정 가게)
- `./dedupe_menu_comments.sql` — 같은 user + content 중복 댓글 NULL 처리

필요 시 사용. 다음 사용자 인스턴스도 동일 케이스 발생하면 비슷한 패턴으로 작성.

---

## 13. 핵심 함정 / 재발 방지 체크리스트

매번 push 후 다음 확인:

- [ ] Vercel `ret-work` 프로젝트 Deployments 의 가장 위 줄이 🟢 Ready 인가? (Error 면 즉시 빌드 로그 확인)
- [ ] `tsconfig.json` 의 exclude 에 `blog` 가 있는가?
- [ ] 새 onclick 핸들러를 inline 으로 만들 때 `JSON.stringify` + `&quot;` escape 패턴 따랐는가? (`_attrArgs` 헬퍼)
- [ ] 새 모달이 `#ov-store-detail`(z-index 980) 위에 떠야 한다면 z-index ≥ 1000 + body 마운트 트릭 적용했는가?
- [ ] 새 서버 API route 추가 시 SSRF / 인증 / rate-limit 고려했는가?
- [ ] 블로그 폴더에 새 ts/tsx 추가 시 메인 빌드 안 깨지는지 Vercel 확인했는가?

---

## 14. 작업 일지 (build 380~388)

- 코스파맵 주변 미방문 가게 마커 추가 (380-381)
- 출석 토글 캐싱 (382)
- 사진 자동 압축 (383)
- **블로그 인프라 구축 + 5편 작성**: 패키지/도메인/Search Console/sitemap 완료
- **Vercel 빌드 8시간 실패 사건**: blog/lib/posts.ts type check 충돌 → tsconfig exclude 추가로 해결
- 영수증 マップで見る SyntaxError + z-index + 가게 그룹 카드 escape 픽스 (384-386)
- 어드민 가게 편집의 Gmap URL → 좌표 자동 추출 (정식/단축 둘 다, 387-388)

---

## 15. 작업 일지 (build 389~428, 다른 PC 작업분)

| build | 내용 |
|---|---|
| **389** | 위치수정 요청 모델 (가게목록 직접편집 → 요청) ★ `store_edit_requests_kind.sql` 실행 필요 |
| **390** | 가게목록 펼침 영역 좌측 쏠림 |
| **391** | 영수증 수정 품목 행 레이아웃 (X 삭제 항상 표시) |
| **392** | OCR 에 지출방법 파싱·선택 + 카테고리 `snack` 추가 + `外食→食事` |
| **393~395** | 카테고리 아이콘 이모지→SVG 통일 |
| **396** | 설정창 글자 크기 (zoom 방식) |
| **397~400** | 치리 공개 모달 개편 (가게사진 + 메뉴별 평점/사진/코멘트) |
| **401~402** | 어드민 가격핀 닉네임 표시 + 코멘트 전용 삭제 |
| **403** | 광고 시청 게이트 컨텍스트별 문구 |
| **404** | 어드민 모바일도 PC 타입(반응형) |
| **405** | 어드민 topbar 버전/빌드 표시 |
| **406** | 치리톡 게시글 → 전체화면 상세 + 이미지 히어로 |
| **407~414** | 새로고침 위치 복원 버그 (여러 라운드) |
| **409** | SW 자동 업데이트 + 새 버전 적용 시 자동 리로드 |
| **415** | nav 진단 패널 제거 |
| **416** | 회귀/죽은코드/중복 정리 |
| **417** | 치리톡 좋아요 멱등성 (`ct_post_likes` + 토글 RPC) |
| **418** | 치리톡 공지 카드 어드민 관리 (`ct_notices`) |
| **419** | 치리토크 베스트(인기) 게시글 자동+수동 (`ct_posts_best`) |
| **420** | 인기글 배너 카드 이미지 URL 텍스트 렌더 픽스 |
| **421** | 치리토크 알림 = 서버 RPC 로만 생성 (보안) |
| **422** | 댓글 수 동기화 + 어드민 가게 삭제 |
| **423** | 알림 분류 픽스 (좋아요/댓글이 시스템 탭 가던 문제) |
| **424~425** | 앱 아이콘 재교체 + 파비콘 |
| **426** | 영수증 원본 이미지 보관 + 어드민 OCR 검수 |
| **427** | 어드민 OCR 검수 ZIP 다운로드 |
| **428** | 자동배포 동작 확인 |

### ⚠️ 다른 PC에서 작업 시 실행 필요한 SQL

- `store_edit_requests_kind.sql` (b389)
- `ct_post_likes.sql` (b417)
- `ct_notices.sql` (b418)
- `ct_posts_best.sql` (b419)
- `ct_admin_moderation.sql` (b421)
- `ct_comment_count_sync.sql` (b422)
- `notify_post_author.sql` (관련 알림 RPC)
- `receipt_images.sql` (b426)

→ 새 PC 에서 작업 전 위 SQL이 Supabase 에 적용되어 있는지 확인.

---

## 16. 도메인 / 메일 인프라 (2026-06-09 신설)

### DNS — Cloudflare

| 레코드 | 콘텐츠 | 프록시 | 비고 |
|---|---|---|---|
| A `retwork.jp` | `216.198.79.1` (Vercel) | **OFF** (회색) | Vercel + Cloudflare 프록시 같이 켜면 충돌 |
| CNAME `blog` | `6d84a6efcce4a...` (Vercel blog) | **OFF** | blog.retwork.jp |
| CNAME `www` | `cname.vercel-dns.com` | **OFF** | www.retwork.jp |
| MX `retwork.jp` × 3 | `route1/2/3.mx.cloudflare.net` | (MX 는 프록시 불가) | Cloudflare Email Routing |
| TXT `retwork.jp` | `v=spf1 include:_spf.mx.cloudflare.net ~all` | — | SPF |
| TXT `cf2024-1._domainkey` | DKIM 키 | — | 메일 인증 |

**🔴 절대 켜지 말 것**: Vercel 레코드(A/CNAME) 의 Cloudflare 프록시 ON → HTTPS 갱신 / Edge 충돌 / 캐시 깨짐.

### 메일 — Cloudflare Email Routing (받기) + Gmail (보내기)

**받기 흐름**:
```
누군가 → info@retwork.jp
       → Cloudflare Email Routing (MX)
       → 본인 Gmail 받은편지함 (minwoo.seo1019@gmail.com 으로 포워딩)
```

**보내기 흐름** (Gmail "다른 주소로 메일 보내기"):
```
Gmail 새 메일 / 답장 → From: info@retwork.jp 선택
                    → smtp.gmail.com:587 + Google 앱 비밀번호로 SMTP 인증
                    → 받는 사람에게 info@retwork.jp 로 표시
```

**주의 — Cloudflare MX 를 SMTP 서버로 쓰면 안 됨**:
Gmail 의 "다른 주소 추가" 시 자동으로 retwork.jp 의 MX (`route3.mx.cloudflare.net`) 를 SMTP 서버로 추측하지만, **Cloudflare Email Routing 은 받기 전용**. SMTP 서버는 `smtp.gmail.com` 으로 수동 변경 필요. (`api_token as username` 에러는 이게 원인)

### 추가 별칭 (필요 시)

Cloudflare 대시보드 → 이메일 → Email Routing → 라우팅 규칙 → "주소 만들기":
- `support@retwork.jp` → 본인 Gmail
- `contact@retwork.jp` → 본인 Gmail
- 또는 **Catch-all** 활성화 → `*@retwork.jp` 모든 주소 본인 Gmail 로

### ads.txt

- 위치: `public/ads.txt`
- 내용: `google.com, pub-6495876616577319, DIRECT, f08c47fec0942fa0`
- AdSense 대시보드의 「찾을 수 없음」 표시는 **AdSense 크롤러 인식 대기** (24~48시간) — 추가 작업 불필요
- 블로그 별도 레포(`SMW-Code/retwork-blog`)에도 동일 ads.txt 필요할 수 있음 (AdSense 에 블로그 따로 등록 시)

---

## 16-B. 블로그 SNS 자동 게시 인프라 (2026-06-10 신설)

### Vercel 환경변수 — `retwork-blog` 프로젝트

| Key | 용도 | 발급처 |
|---|---|---|
| `ADMIN_PASSWORD` | `/admin` 비번 | 본인 정함 |
| `GITHUB_TOKEN` | `/api/publish` 의 GitHub 커밋 | github.com/settings/tokens (Contents:write) |
| `X_API_KEY` | X (트위터) Consumer Key | developer.x.com 의 App |
| `X_API_SECRET` | X Consumer Secret | 동상 |
| `X_ACCESS_TOKEN` | X user-context Access Token | 동상 (App permissions: Read and write 필수) |
| `X_ACCESS_TOKEN_SECRET` | X Access Token Secret | 동상 |
| `THREADS_USER_ID` | Threads 본인 user ID (숫자) | `GET https://graph.threads.net/v1.0/me?access_token=...` 응답의 `id` |
| `THREADS_ACCESS_TOKEN` | Long-lived Access Token (60일) | developers.facebook.com → Threads API 「사용자 토큰 생성기」 |
| `BLOG_PUBLISH_KEY` *(옵션)* | 외부 자동화용 별도 키 | 본인이 32+ 자 랜덤 |

### 함정 / 가르침 받은 점

- **X 무료 plan 폐지** (2024 말~2025) — 이제 무조건 크레딧 구매. 다행히 게시당 비용은 작음 (월 30편이면 매우 저렴)
- **App permissions「Read and write」 필수** — 만약 「Read」 only 면 403. 권한 변경 후 **Access Token 재발급** 필요 (옛 토큰은 옛 권한 그대로)
- **Threads: 콜백 URL 저장 에러는 무시 OK** — 우리는 OAuth flow 안 쓰고 직접 발급된 token 만 사용. 「사용자 토큰 생성기」 → 「Threads 테스터 추가」 → 본인 계정 초대 수락 → 「생성」 으로 Long-lived token 직접 발급
- **Threads 계정 공개(Public) 필수** — 비공개 계정은 token 발급 불가
- **수정 모드에서 X 자동 게시 기본 OFF** — 같은 글의 트윗을 다시 보내면 X 가 403 Duplicate 로 거부. UI 가 자동으로 체크박스 해제
- **이미지 base64 4.5MB 한계** — `compressImage(1600, 0.85)` 가 입력 단계에서 처리. 만약 한계 초과하면 fetch `.json()` 이 HTML(413) 을 파싱 시도하다 `"Unexpected token 'R', \"Request En\"..."` 로 뜸

### SNS 게시 API

```bash
# 단일 SNS 게시 (어드민 발행 시 자동 호출)
POST /api/sns/x
POST /api/sns/threads
{ "password": "...", "title": "...", "description": "...", "url": "...", "tags": [...], "customText"?: "..." }

# 기존 글 재공유 (slug 만으로 자동 메시지 생성)
POST /api/sns/share-by-slug
{ "password": "ADMIN_PASSWORD or BLOG_PUBLISH_KEY",
  "slug": "...",
  "platforms": ["x", "threads"],
  "customX"?: "...", "customThreads"?: "..." }
```

### 운영 흐름

| 상황 | 방법 |
|---|---|
| **새 글 발행** | `/admin` 새 글 → 자동으로 SNS 체크박스 ON → 🚀 발행 |
| **옛 글 재공유** | `/admin` 글 목록 → 글 옆 [X] [Threads] [X + Threads] 버튼 클릭 |
| **외부 자동화** (curl/봇) | `/api/sns/share-by-slug` 호출 (BLOG_PUBLISH_KEY 사용 권장) |

### 글 작성 — admin 에디터 신규 기능 정리 (2026-06-09~10)

- ✂️ 이미지 회전·자르기 모달 (대표 / 블록 둘 다)
- 🎨 글 테마 색상 / 강조 카드 색상 (10테마 + 커스텀 hex)
- ➕ 라인 블록 (구분선)
- 🎨 폰트 스타일 (서체 / 사이즈 / 굵기 / 색상) — heading / text / card 별
- 📄 마크다운 출력 코드뷰 (펼치기/접기)
- 🤖 자동 이미지 압축 (모든 업로드 1600px / JPEG 85)
- 📤 글 목록 SNS 재공유 버튼

---

## 17. Git 워크플로우 — 베타 시점 전환

`origin/dev` 브랜치는 이미 존재. Vercel 이 자동으로 dev → preview URL 생성 중.

### 현재 (베타 전)
```
main ──(직접 푸시)──→ retwork.jp (prod)
```

### 베타 시작 후 (제안)
```
main (freeze, 베타 prod) ──핫픽스만──
  ↑
  ↑ 머지
  ↑
dev ──(개발 푸시)──→ preview URL (또는 beta.retwork.jp)
```

### 베타 시점 전환 절차

```bash
# 1. 베타 시작 직전 — main 동결 + 태그
git checkout main
git tag v1.0-beta -m "Beta release for testers"
git push origin v1.0-beta

# 2. 새 개발은 dev 에서
git checkout dev
git merge main
# 코드 수정...
git push origin dev   # → preview URL 자동 배포

# 3. 베타 핫픽스
git checkout main
# 작은 fix
git push origin main  # → retwork.jp 즉시 반영
git checkout dev && git merge main && git push  # dev 에도 동기화

# 4. 정식 출시
git checkout main
git merge dev
git tag v1.0
git push origin main --tags
```

### 베타 URL 분리 (옵션 — 5분 작업)

베타 테스터에게 일반 사용자와 다른 URL 주려면:

1. Cloudflare DNS → CNAME `beta` → `cname.vercel-dns.com` (프록시 OFF)
2. Vercel → ret-work 프로젝트 → Settings → Domains → `beta.retwork.jp` 추가
3. **Branch** 필드에 `dev` 입력 → 저장
4. → `beta.retwork.jp` 는 dev 빌드, `retwork.jp` 는 main 빌드

### Branch 보호 (옵션)

GitHub Settings → Branches → Add rule → `main`:
- ✅ Require pull request before merging
- ✅ Require status checks (Vercel build pass)

→ 베타 동결 후 실수로 main 푸시 방지. 솔로 개발자라면 거추장스러울 수 있어 선택.

---

## 18. 운영자 / 연락처 표기 통일 정책 (2026-06-09 신설)

본명 / 개인 이메일 노출을 모두 익명화:

| 위치 | 표기 |
|---|---|
| 운영자 | **`RetWork 編集部`** |
| 연락처 메일 | **`info@retwork.jp`** |
| 회사 정보 (소재지) | `東京都中央区晴海（日本）` (유지) |

### 적용된 페이지 (15개 파일 / 36 위치)

- `public/about.html`, `contact.html`, `privacy.html`, `terms.html`
- `public/index.html` (메타 author + JSON-LD + 푸터)
- `public/blog/*.html` (11편 — JSON-LD author + 본문 著者)

### 검색용 명령

향후 본명/개인메일이 새로 들어가지 않았는지 정기 점검:
```bash
grep -rli --exclude-dir=node_modules --exclude-dir=.next --exclude-dir=.git "SEO MINWOO\|minwoo\.seo" .
```
→ 결과 0건이면 OK.

### 모킹 페이지 (검색 차단)

`prototype.html` / `home-mockup.html` / `design-compare.html` 의 더미 텍스트도 `ゲ/ゲストユーザー` 로 익명화 + `robots.txt` 에서 색인 차단.

---

## 19. 다른 PC 에서 이어 작업 시 체크리스트

1. `git pull` (main 최신)
2. **HANDOFF.md 읽기** (이 파일)
3. `npm install` (root)
4. 환경변수 확인 (`.env.local` 또는 Vercel Settings):
   - `GOOGLE_VISION_API_KEY` (또는 `VISION_KEY` 등 대체명)
   - `OPENAI_API_KEY`
   - `VAPID_PUBLIC_KEY` / `VAPID_PRIVATE_KEY`
   - (AdSense 승인 후) `NEXT_PUBLIC_ADSENSE_CLIENT`
5. **Supabase 적용 SQL 확인** (위 §15 의 `ct_*.sql` 등)
6. `npm run dev` 로 build 428 정상 동작 확인
7. 베타 시작 시점이면 → `git checkout dev` 후 작업
8. 메일 보내기 / 받기 테스트 (info@retwork.jp 가 본인 Gmail 로 오는지)

### 도움말 한 줄
- Vercel 대시보드: https://vercel.com/SMW-Code (ret-work / retwork-blog)
- Cloudflare 대시보드: https://dash.cloudflare.com (retwork.jp)
- Supabase: https://supabase.com/dashboard/project/fkvfbxfgidrvymoftkdd
- AdSense: https://www.google.com/adsense
- Search Console: https://search.google.com/search-console

---

## 20. 알려진 미해결 / 분석 중

- **새로고침 후 마지막 화면 복원** — b407~b414 까지 여러 라운드 픽스. 현재 안정적이지만 일부 엣지 케이스 (PWA 백그라운드 종료 후 재시작) 에서 홈으로 복귀 가능성. 추가 사용자 보고 시 분석.
- **store_menu_comments.rating NOT NULL 제약** — 코멘트-only insert 시 실패 가능 (b398). 필요 시 컬럼 nullable 로.
- **store_comments_admin_delete RLS 정책** — Supabase 에 `admin_rls_policies.sql` 실행 안 됐을 가능성 (b401). 어드민 댓글 삭제가 유저 페이지에 반영 안 되면 SQL 재실행.
- **backup-b391-395 브랜치** — 어드민 가격핀→어드민 편집 회귀수정 보관. 필요 시 재적용.
