# RetWork (チリつも) — HANDOFF (build 378 시점)

> 다른 컴퓨터에서 이어서 작업할 때 이 파일부터 읽으면 현황 파악 완료.
> 최신 빌드: **build 378** · 도메인: **retwork.jp** · 일본 시장 타겟 영수증 OCR + 가성비 가게 정보 공유 PWA.

---

## 0. 프로젝트 한눈에

- **단일 파일 PWA**: `public/index.html` (~25,000 lines) + `public/sw.js`
- **백엔드**: Supabase (Postgres + Auth + Storage + Realtime)
- **배포**: Vercel 자동 (`main` push → 즉시 반영)
- **모드**: ReceiptIQ (가계부) ↔ チリつも (가성비 맵)
- **i18n**: 4언어 (ja / ko / en / zh) — `data-i18n` 속성 + `I18N` 객체 + CMS

---

## 1. 빌드 / 캐시

```
public/index.html → window.__APP_BUILD__ = 378;
public/sw.js      → CACHE_NAME = 'receiptiq-v0.9.0-b378';
```

**캐시 정책**: HTML 은 네트워크 우선 (`no-store`), 나머지 정적 자원은 캐시 우선. 사용자에게는 항상 `Ctrl+Shift+R` 강제 새로고침 안내.

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
- `admin_rls_policies.sql` — 어드민 INSERT/UPDATE/DELETE + 본인 정책 (price_pins / store_menu_cards / store_menu_comments / store_comments / stores / receipts / items / store_menu_photos)
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

## 3. SVG 아이콘 시스템 (`window.__LICO_SET__`)

라인 ~24825. 50+ Lucide-style stroke SVG. 사용:

```js
icon('camera', 26, 'var(--green)')  // 인라인 SVG 문자열 반환
```

또는 마크업으로:
```html
<span class="lico" data-lico="camera" data-size="20" data-color="var(--text-2)"></span>
```

`_renderLicos()` + MutationObserver 가 자동 변환.

**최근 추가**: `share`, `more`.

---

## 4. 주요 흐름

### 영수증 OCR → 저장
1. 카메라/이미지 선택 → `/api/vision` (Node runtime, GPT Vision)
2. `result.date` 는 **원본 표기** ("26年6月4日", "平成26年6月4日") — build 346 부터 GPT 환산 X
3. 클라이언트 `_sanitizeReceiptDate` 가 5가지 패턴 처리 (元号/2자리/4자리/ISO)
4. OCR 결과 화면에 가게명/날짜(input type=date)/카테고리/품목/총액 편집
5. 저장 흐름:
   - **가계부에 저장하기** → `_doSaveOcrResult()` (광고 → receipts insert)
   - **가계부 저장 ＆ 치리츠모 공개** → `_doSaveOcrResult()` (즉시) + `openChiriPublish()` 모달 → `submitChiriPublish()` (price_pins insert + store_menu_cards 중복 방지)

### 가게 상세 모달 (`ov-store-detail`)
- panel: `border-radius:24px 24px 0 0`, `box-shadow:0 -8px 32px rgba(0,0,0,.28)`
- overlay: `background:rgba(0,0,0,.85)`, blur 없음 (build 378)
- 영역: 헤더 → 사진(H=244px) + 사이드 4 버튼(width 96px, 각 ~55px) → Google 정보 → 광고 → 메뉴 카드 그리드 → 방문자 리뷰 → 비공개 메모
- 사이드 4 버튼: 📷(SVG camera) / 🗺️(map_pin) / 🌐(globe) / 📤(share)
- 점점점 메뉴: 수정 요청 / 닫기

### 사진 슬라이드 + 전체화면 뷰어
- 가게 사진: `store_photos` + `store_community_photos` 통합, 대표 우선
- 메뉴 카드 사진: `store_menu_cards.image_url` + `store_menu_photos`
- 뷰어: `ov-sd-photo-viewer` (z-index 99999, body 마운트), ‹/›/✕/Esc + 키보드

### 어드민 PC 모드
- `_admPcDrilldownTo(modalId, opts)` → 시트를 콘텐츠 영역에 마운트
- 가게 편집 모달 → 가게 정보 + 사진 관리 + 대표 메뉴 + 위치 (구글 맵)
- 메뉴 카드 수정 → 풀스크린 (`ov-admin-edit-menu-card`)
  - 기본 정보 (이름 / 가격 / 카테고리 select / 대표 메뉴)
  - 사진 (legacy image_url + store_menu_photos, fuzzy 매칭으로 sibling 카드 사진도 표시 + 가져오기)
  - 댓글/평점 (content 빈 row 는 숨김)
- 가게핀 페이지에 메뉴 카드 영역 추가 (build 355)

### 영수증 중복 의심 관리 (build 362)
- 같은 (user_id, store_name, receipt_date, total_amount) 2+ 행 → 가장 오래된 1개 = 원본, 나머지 = 중복 의심
- 상단 배너 + 단건 🗑️ + 일괄 삭제

### 댓글 정책 (build 364, 376)
- `store_comments` = 가게 단위 (메뉴 댓글 수정 시 자동 동기화 + 닉네임은 `profiles` 최신값 표시)
- `store_menu_comments` = 메뉴별 평점 + 직접 입력 댓글 (치리 공개 시 rating 만, content NULL)
- content 빈 row 는 화면에서 숨김

---

## 5. Web Push (build 306~)

- VAPID 키: Vercel 환경변수 `VAPID_PUBLIC_KEY` / `VAPID_PRIVATE_KEY`
- 구독: `/api/push/subscribe`
- 발송: `/api/push` (cron + 운영팀 메시지)
- GitHub Actions cron — `.github/workflows/attendance-push.yml` (출석 슬롯 8:00/16:00 JST)
- TWA APK: PWA Builder, package=`jp.retwork.app`, SHA-256 등록 (`/public/.well-known/assetlinks.json`)

---

## 6. 최근 build 흐름 (327~378)

### Phase A: 영수증/날짜/OCR
- **323**: 일본 元号 / 2자리 연도 파싱 (1차)
- **328-331**: 어드민 영수증 → 가게 위치 수정 흐름
- **332**: 스캔 메뉴 3옵션 재구성
- **341**: 프로필 ✏️ 색상 + 받은쪽지함 mail 아이콘
- **342**: OCR 결과 저장 버튼 라벨 명확화 (`가계부 저장 ＆ 치리츠모 공개`)
- **343**: 치리 공개 시 가계부 저장 보장 (광고 콜백 의존 제거)
- **344-346**: GPT 환산 책임 제거 — 원본 형식 그대로 반환, 클라이언트가 모두 처리

### Phase B: 어드민 가게핀 / 메뉴카드 관리
- **347**: 가게핀 페이지 가게 편집 / 삭제 / 편집 버튼 3개 fix
- **348**: 메뉴카드 매칭 (maybeSingle → fuzzy + sibling cards) + 중복 등록 방지
- **349~353**: store_photos / store_menu_photos 스키마 + Supabase Storage bucket
- **350~352**: 어드민 가게 사진 관리 UI (업로드/대표/순서/삭제)
- **351**: 메뉴 카드 편집 풀스크린 모달
- **354**: store_name fuzzy 매칭 (NFKC + 공백 제거)
- **355**: 가게핀 페이지에 메뉴 카드 영역 추가
- **356**: ← 뒤로 + 브레드크럼 정리
- **357**: 이미지 onerror graceful fallback

### Phase C: 유저 사진/메뉴 슬라이드
- **358**: 가게 상세 사진 슬라이드 + 전체화면 뷰어 (ov-sd-photo-viewer)
- **359**: 메뉴 카드 상세에도 슬라이드 + 뷰어 적용
- **360-361**: stacking context 회피 — body 마운트
- **362**: 어드민 영수증 중복 의심 표시 + 일괄 삭제
- **363**: 영수증 편집 모달에 🗑️ 삭제 버튼

### Phase D: 데이터 정합 / 디자인
- **364**: 치리 공개 시 메뉴별 content 복제 방지 (`content: null`)
- **365**: 화면 단 content 빈 row 필터
- **366**: 가게 상세 메뉴 카드의 어드민 컨트롤(◀▶☆) 제거
- **367-368**: 가게 상세 사이드 액션 영역 — 점점점 → 사이드 4번째 공유 버튼
- **369**: 가게 상세 이모지 → SVG (사이드/Google 정보/today)
- **370**: 메뉴 댓글 수정 시 가게 단위 방문자 리뷰 동기화
- **371**: 사이드 4 버튼 사진 H 에 맞춰 배율 확대 (icon 26, 글자 12)
- **372-374**: 모달 dim 강화 + RLS 정책 보강 (store_comments own + admin)
- **375**: store_comments 에 updated_at 컬럼 없음 → payload 제거
- **376**: 방문자 리뷰 닉네임을 profiles 최신값으로
- **377-378**: 모달 box-shadow 단순화 + backdrop-filter 제거 + dim 0.85

---

## 7. 다음 작업 후보

- 메뉴 카드 순서 배열 (어드민이 드래그 또는 ↑↓ 으로 sort_order 설정 — UI 일관성)
- 메뉴 카드 사진 — store_menu_photos 의 어드민 UI 보강 (이미 build 351 에 있음, 다듬기)
- 가게 상세 모달 디자인 미세 조정 (필요 시)
- 다국어 미적용 라벨 발견 시 i18n CMS 사용 (`openAdminI18n`)

---

## 8. 환경 / 명령

### 로컬 개발
```bash
# Next.js 16 dev (Vercel 환경)
cd C:\Users\minus\Desktop\receiptiq
npm run dev
```

### 배포
```bash
git push   # main 푸시 → Vercel 자동 배포
```

### Supabase
- 프로젝트: `fkvfbxfgidrvymoftkdd.supabase.co`
- SQL Editor 에서 `./*.sql` 파일 실행
- Storage Dashboard 에서 `store-photos` bucket 관리

---

## 9. 자주 쓰는 디버깅 console 로그

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
```

---

## 10. RLS / 보안 패턴

- `auth.uid()` 기반 본인 정책
- 어드민: `EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE)`
- 모든 INSERT/UPDATE/DELETE 코드에 `.select()` + length 검증 추가 (RLS 차단 시 사용자에게 명시적 알림)
- 새 테이블 추가 시 `admin_rls_policies.sql` 에 정책 추가하는 패턴

---

## 11. 데이터 정리 유틸 SQL (수동 1회성)

`./merge_duplicate_menu_cards.sql` — 메뉴 카드 통합 (특정 가게)
`./dedupe_menu_comments.sql` — 같은 user + content 중복 댓글 NULL 처리

필요 시 사용. 다음 사용자 인스턴스도 동일 케이스 발생하면 비슷한 패턴으로 작성.
