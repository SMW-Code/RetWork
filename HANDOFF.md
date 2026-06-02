# 🔄 RetWork (チリつも) — 인수인계 문서

> **최종 갱신**: 2026-06-02 / build 282 / v0.9.0
> 다른 컴퓨터에서 이어 작업할 때 이 파일부터 읽으세요.

---

## 📌 프로젝트 개요

- **서비스명**: RetWork (チリつも)
- **타겟 시장**: 일본 (영수증 OCR + AI 가계부 + 절약 커뮤니티 PWA)
- **배포 URL**: https://retwork.jp (Vercel 자동 배포)
- **GitHub**: SMW-Code/RetWork (`main` 브랜치 → Vercel 자동 빌드)
- **로컬 경로**: `C:\Users\minus\Desktop\receiptiq`
- **구조**: 단일 파일 PWA — `public/index.html` (~19,500+ 줄) + `public/sw.js`
- **백엔드**: Supabase (`fkvfbxfgidrvymoftkdd.supabase.co`)
- **현재 버전**: `v0.9.0` (semantic) / `build 282` (internal)

---

## 🚦 현재 상태 한눈에 (build 263~282 최근 작업)

### 🎯 PC 어드민 풀스크린 시스템 (build 268~282, 인디고 #172C58)

**진입**: 설정 → "어드민 대시보드" → `window.innerWidth >= 768` 이면 새 풀스크린 화면.
모바일(<768px) 은 기존 시트 (`ov-admin`) 그대로.

**구조**:
```
ov-admin-pc (z-index:9500, position:fixed)
├ 톱바 (인디고): RetWork Admin | [전체] [언어시트] [치리관리] [광고관리] | email ✕
├ 사이드바 (240px, F4F5F8): 톱바 탭별 동적 메뉴
└ 콘텐츠 영역 (flex:1): 메뉴 클릭 시 마운트
```

**3가지 메뉴 패턴**:
1. **mount** — 기존 어드민 모달의 `.sheet` 를 콘텐츠 영역으로 이동 (사용자/영수증/가게/공지/i18n/단가/스토어상품/광고시청 등)
2. **customRender** — PC 전용 신규 화면 직접 렌더 (광고 페이지/위치, 치리 발급 통계)
3. **fn** — 폴백, 기존 모달 호출 (점진적 마이그레이션 중)

**핵심 헬퍼**:
- `_admPcMountSheet(modalId, dataLoader)` — 시트 마운트 + 스타일 백업/덮어쓰기 + sheet-handle/✕ 숨김
- `_admPcUnmountAll()` — 콘텐츠 영역의 시트들을 원래 모달로 복귀
- `_admPcCloseAllAdminModals()` — `.overlay.open` 일괄 닫기 (PC/설정 제외)
- 위 3개가 메뉴/탭/PC 닫기 시점에 자동 호출되어 모달 누적/오염 방지

### 🎨 광고 페이지/위치 화면 (build 275~280) — 톱바 광고관리 > 광고 페이지/위치

`AD_POSITIONS` 배열에 16개 광고 위치 정의 (페이지 그룹화):

| 페이지 | context | 유형 | 단가 |
|---|---|---|---|
| home | home | 인라인 | ¥0.15 |
| receipt | save / modal | 풀스크린 / 인라인 | ¥17 / ¥0.15 |
| chirimap | map / store / chiri / menu_photo / private | 인라인 + 풀스크린 4 | ¥0.15 + ¥17 |
| chiritalk | feed / comment_quota | 인라인 + 풀스크린 | ¥0.15 + ¥17 |
| reward | reward / bonus | 풀스크린 2 | ¥17 |
| attendance | attendance / attendance_auto / attendance_modal_auto | 풀스크린 + 자동재생 2 | ¥17 + ¥0.15 |
| referral | referral | 풀스크린 | ¥17 |

**각 카드별 로컬 광고 등록**: 카드 하단 "🎨 로컬 광고 N/M개" 버튼 → 광고 목록 모달 (`ov-apc-local-ad`) → "+ 새 광고 추가" → **기존 `ov-admin-ad-form` 재사용** (이미지 업로드 + 드래그 크롭 + 줌 + 슬라이더/픽셀 양방향 완전 작동).

`ov-admin-ad-form.zone` select 에 AD_POSITIONS context 12종 추가 (optgroup 분류).

**클라이언트 표시 (build 278~)**:
- `_injectAd(containerId, slotKey, contextOverride)` — 3번째 파라미터 신규
- `_pickLocalAd(zone, contextOverride)` — context 우선, zone 폴백
- 풀스크린: `ctOpenFullscreenAd` 에서 mode 자체를 contextOverride 로 전달
- 인라인: `showAdModal` 의 `_adContext` 전달
- `_renderLocalAd`: `width_px/height_px` 우선, 없으면 `width_pct/aspect_pct`

### 📊 치리 발급 통계 화면 (build 282) — 톱바 치리관리 > 치리 발급

`coin_transactions` 기반 PC 전용 신규 화면 (customRender):
- 기간 필터 (오늘/7일/30일/1년/전체)
- 요약 4카드 (발급/사용/순/트랜잭션수 + ¥환산)
- 타입별 발급 (14종 CHIRI_TYPE_LABELS) — 발급량 순 정렬
- 사용자별 Top 10 — profiles 닉네임/이메일 매칭 + 인디고 랭크 배지

### 🌐 언어시트 페이지별 분리 (build 281) — 톱바 언어시트

기존 `ov-admin-i18n` 1개 모달 재사용, 사이드바에 prefix 별 15개 메뉴:
전체 / 홈 / 인증 / 영수증 / 가게 상세 / 치리톡 / 리워드 / 설정 / 프로필 / 광고 / 토스트 / 카테고리 / 테마 / 모드 / 프리미엄.

`_admI18nLoadWithPrefix(prefix)` — `openAdminI18n()` 호출 후 prefix select 동적 옵션 채워질 때까지 재시도 → 매칭 시 선택 + `_loadAdminI18n()` 재호출.

### 💰 추천 통계 카드 (build 263) — 설정창 친구 초대

`get_referral_status` RPC 확장 (`referral_v2_stats.sql` 실행 완료) → 누적 통계 3개 (`total_referred / total_claimed / total_earned`).

설정창 친구 초대 섹션에 3분할 통계 카드:
- 👥 추천 친구 N명
- ✨ 받은 치리 +N
- ⏳ 대기 보상 N건

### 🛠️ 가게 수정요청 모달 (build 264~267) — 치리맵 가게상세 ⋮ → ✏️ 修正リクエスト

- z-index 99999 + body 이동 (가게상세 모달의 stacking context 회피)
- 바텀시트 통일 → PC(640px+) 는 중앙 팝업으로 반응형 분기
- CSS 미디어쿼리 `@media (min-width:640px)` 로 분기 강제

---

## ⚠️ 검증 필요 (배포는 완료 but 미확인)

### LINE OAuth (build 255 이후)
- `line-v2` Custom Provider 사용 (`provider: 'custom:line-v2'`)
- **다음 액션**: Supabase Dashboard → Custom Providers → `line-v2` Edit → Manual configuration:
  ```
  Authorization: https://access.line.me/oauth2/v2.1/authorize
  Token:         https://api.line.me/oauth2/v2.1/token
  UserInfo:      https://api.line.me/oauth2/v2.1/userinfo  ⭐
  JWKS:          https://api.line.me/oauth2/v2.1/certs
  Issuer:        https://access.line.me
  ```

### 회원가입 400 (build 249 이후)
- build 259 에서 이메일 직접 가입 자체 숨김 → 우선순위 낮음. 향후 OAuth 만 사용.

---

## 🐛 알려진 이슈 / Workaround

### 1. Supabase Dashboard Custom OAuth Provider 버그
- `custom:line` provider 수정/삭제/비활성화 모두 불가 (`identifier must start with 'custom:' prefix` 에러)
- 회피: `line-v2` 새 identifier 로 재생성, 클라이언트 `provider: 'custom:line-v2'` (build 255)
- 장기: Supabase Support 티켓 제출 (https://supabase.com/dashboard/support/new)

### 2. PWA OAuth 외부 브라우저 분리
- PWA standalone 에서 OAuth 클릭 시 외부 브라우저 열림 — OS 표준 동작
- build 254/256~258 에서 보강 (visibilitychange / `riq_oauth_from_pwa` 표식 / `?pwaret=1` URL / `📱 アプリに戻る` 버튼)

### 3. 자동재생 광고 통계 미수집
- `attendance_auto`, `attendance_modal_auto` 등 자동재생 광고는 ad_views 에 기록 안 됨 (HTML 안 SVG 그라디언트 placeholder)
- 로컬 광고 등록은 가능하지만 실제 표시는 별도 작업 필요 (`_injectAd` 호출 없음)

---

## 🔐 Supabase 설정 현황

### Auth Providers
| Provider | 상태 | 비고 |
|---|---|---|
| Email + Password | ⚠️ 활성 but 로그인 화면에서 숨김(build 259) | OAuth 만 노출 |
| Google | ✅ 활성 | |
| Apple | ❌ 미설정 | UI "🍎 Apple 로그인은 준비 중이에요" 토스트 |
| **LINE (custom:line)** | 🚨 깨짐 | Dashboard 버그로 사용 X |
| **LINE (custom:line-v2)** | ⏳ 검증 중 | Manual config + userinfo URL 명시 필요 |

### DB Schema 주요 테이블
- `profiles` — referral_code, coin_balance, is_admin, nickname, email
- `receipts` + `items` — 영수증
- `store_comments`, `store_menu_cards`, `price_pins`, `stores`
- `ct_posts`, `ct_comments`, `ct_notifications` — 치리톡
- `announcements`, `store_items`, `banned_words`, `banned_users`
- `comment_reports`, `store_edit_requests`
- `ad_views`, `coin_transactions` — 통계
- `comment_quota_grants` — 댓글 한도 광고 권한 (build 250+)
- `referral_rewards` — 추천 보상 pending/claimed (build 261+)
- **`local_ads`** — 로컬 광고 (zone 기반, build 276~)
- **`ad_revenue`** — 월별 광고 수익 수동 입력

### RPC 함수 주요
- `client_add_coins(amount, type, description)` — 코인 적립
- `get_comment_quota_today()` / `grant_comment_quota(p_extra)`
- `get_referral_status()` — pending/claimed_today/cap/claimable_today + total_referred/total_claimed/total_earned (build 263+)
- `claim_referral_reward()` — 광고 시청 후 +200치리 청구
- `redeem_referral(p_code)` — 친구 가입 시 pending 적립
- `local_ad_bump(p_id UUID, p_kind TEXT)` — impression/click 카운트

### SQL 파일 실행 상태 (현재까지 누적)
- ✅ `security_patch_v4.sql` — 베타용 (코인 한도/쿨다운 우회). v1.0.0 직전 `v3` 재실행으로 복원 필요
- ✅ `referral_v2.sql` — 추천 보상 대기/광고 청구 모델
- ✅ `referral_v2_stats.sql` — get_referral_status 통계 확장
- ✅ `store_edit_requests.sql` — 가게 수정요청 테이블
- ✅ `local_ads.sql` — 로컬 광고 테이블 + bump RPC
- ✅ `local_ads_px.sql` — width_px/height_px 컬럼 ALTER

---

## 🎬 광고 시스템 매트릭스

### `_BYPASS_ADS = true` (베타, build 248~)
| 항목 | 베타 | 정식(v1.0.0) |
|---|---|---|
| 광고 모달 표시 | ✓ | ✓ |
| 적립 일일 한도 (코인) | ❌ 우회 | ✓ |
| 출석 광고 쿨다운 | ❌ 우회 | ✓ |
| 댓글 1일 5회 한도 | ❌ 우회 | ✓ |

### 광고 위치 16개 (AD_POSITIONS)
풀스크린 9개 (¥17/시청), 인라인 5개 (¥0.15/노출), 자동재생 2개 (¥0.15/노출).

**클라이언트 표시 우선순위**:
1. 활성 로컬 광고 (zone === context, priority DESC)
2. AdSense (승인 후)
3. 정적 placeholder

### 수익 추정
- 1인 1일 출석 모두 시청: **¥154.80 매출 / ¥12 보상 / ¥142.80 순이익 / 92.2% 마진**
- MAU 1만 / 출석률 70% / 30일: **약 ¥32,500,000 매출 (월 약 2,990만엔 순이익)**

---

## 🎨 PC 어드민 코드 위치 (Grep 없이 바로 찾기)

| 기능 | 줄번호 (대략) | 함수/요소 |
|---|---|---|
| PC 어드민 HTML | 2527+ | `#ov-admin-pc` |
| openAdminDashboard PC 분기 | ~17580 | `window.innerWidth >= 768` |
| 메뉴 정의 `_admPcMenus` | ~17610 | overview/i18n/chiri/ads |
| `_admPcMountSheet` | ~17700 | 시트 마운트 헬퍼 |
| `_admPcCloseAllAdminModals` | ~17680 | 모달 일괄 닫기 |
| AD_POSITIONS | ~17775 | 광고 위치 16개 |
| `_admPcRenderAdPages` | ~17820 | 광고 페이지/위치 렌더 |
| `_admPcRenderChiriIssued` | ~18030 | 치리 발급 통계 렌더 |
| `_admI18nLoadWithPrefix` | ~18200 | i18n prefix 자동 필터 |
| `_admPcOpenAdFormForContext` | ~18240 | 카드 → 기존 광고 폼 |
| `ov-apc-local-ad` HTML | ~3540 | 위치별 로컬 광고 모달 |

---

## 🚀 다음 작업 우선순위

### P0 — 검증
1. **LINE OAuth 정상 작동 여부** (Supabase Dashboard 측 Manual config)

### P1 — Phase 3 마무리
2. **Phase 3.C 교환요청 처리** — 치리스토어 교환 신청 워크플로우 (신규 테이블 필요 가능)

### P2 — 정식 출시 (v1.0.0) 전
3. `_BYPASS_ADS = false` 변경 + `security_patch_v3.sql` 재실행
4. Apple Developer Program 가입 → Apple OAuth 활성화
5. LINE Email Permission 신청 (Scope `email` 추가)
6. AdSense 재심사 신청
7. 광고 페이지/위치 화면의 자동재생 광고 실제 표시 로직 통합

### P3 — 추가 기능
8. PC 어드민 광고 페이지/위치에서 ON/OFF 토글 실제 동작
9. PC 어드민 검색/필터 강화 (글로벌 ⌘+K)
10. TWA (Bubblewrap+Play스토어) 전환 검토

---

## 🛠 개발 명령

```bash
cd C:\Users\minus\Desktop\receiptiq

# 변경 후 배포 (build bump 후)
git add public/index.html public/sw.js
git commit -m "메시지 (build XXX)"
git push
# → Vercel 자동 배포 (1~2분)
```

### Build bump 절차 (매 push 마다)
1. `public/index.html` 의 `window.__APP_BUILD__ = XXX;` 1 증가
2. `public/sw.js` 의 `const CACHE_NAME = 'receiptiq-v0.9.0-bXXX';` 동일 증가
3. 커밋 메시지 `(build XXX)` 포함

---

## 📂 주요 파일

```
receiptiq/
├── public/
│   ├── index.html       ⭐ 메인 (~19,500+ 줄)
│   ├── sw.js            ⭐ Service Worker
│   ├── about.html / privacy.html / terms.html / contact.html
│   ├── sitemap.xml      (16 URLs)
│   ├── robots.txt
│   ├── manifest.json    (Blob URL 인라인)
│   ├── icons/
│   └── blog/            (10개 글)
├── security_patch_v3.sql     ⏳ 정식 출시 시 재실행 (한도 복원)
├── security_patch_v4.sql     ✅ 베타 적용 중 (한도 우회)
├── referral.sql              (v1, 즉시 지급 — 안 씀)
├── referral_v2.sql           ✅ pending/광고 청구 모델
├── referral_v2_stats.sql     ✅ get_referral_status 통계 확장
├── store_edit_requests.sql   ✅ 가게 수정요청 테이블
├── local_ads.sql             ✅ 로컬 광고 + bump RPC + ad_revenue
├── local_ads_px.sql          ✅ width_px/height_px ALTER
├── HANDOFF.md                ⭐ 이 파일
└── AGENTS.md / CLAUDE.md
```

---

## 🔑 시크릿 / 자격증명

⚠️ **절대 채팅이나 코드에 직접 작성하지 말 것**

| 자격증명 | 위치 |
|---|---|
| Supabase service_role key | Supabase Dashboard → Project Settings → API |
| Supabase Anon Key | 코드의 `_sb` 초기화 (HTML 내 public OK) |
| LINE Channel ID | `2010255617` (공개 OK) |
| LINE Channel Secret | LINE Developers Console (재발급 가능) |
| Google OAuth Client | Google Cloud Console → Supabase 입력됨 |
| Supabase Personal Access Token | https://supabase.com/dashboard/account/tokens |
| Apple Developer Key | (미가입 상태) |

---

## 📞 이슈 발생 시 디버깅

### 1. Vercel 배포 실패
- Vercel Dashboard → Deployments → 최신 실패 로그 (단일 HTML 빌드라 거의 immediate fail)

### 2. Supabase 응답 이상
- Supabase Dashboard → Logs → API/Auth/Database
- RLS 위반 시 `permission denied`

### 3. PWA SW 캐시
- 폰: 앱 강제 종료 → 앱 정보 → 저장공간 → 캐시 삭제
- PC: DevTools → Application → Service Workers → Unregister → Hard Reload

### 4. PC 어드민 동작 이상
- 콘솔에서 `openAdminPc()` 직접 호출
- `_admPcMenus` 메뉴 정의 확인
- 마운트된 시트는 `document.querySelectorAll('[data-original-parent]')`

### 5. 로컬 광고 표시 안 됨
- 콘솔: `_localAdsByZone` 확인 (zone 별 광고 배열)
- `_loadLocalAds()` 호출 후 재확인
- 컨텍스트 매칭: `_pickLocalAd(slotKey, contextOverride)` 직접 호출

---

## 🔥 절대 잊으면 안 되는 것

1. **단일 HTML 파일** (`public/index.html`) = 전부. React/Vue 아님
2. **Build bump 안 하면 사용자가 새 버전 못 봄** — sw.js + index.html 둘 다
3. **`_BYPASS_ADS = true` 는 베타용** — 정식 출시 전 `false` + SQL v3 재실행
4. **emoji 는 사용자 명시 요청 있을 때만** (CLAUDE.md 룰)
5. **사용자(minwoo) 는 한국인** — 한국어 응답이 기본, UI 는 일본어
6. **PC 어드민 진입 임계값 768px** — DevTools 열어도 PC 모드 진입 가능
7. **카드별 로컬 광고 등록은 기존 `ov-admin-ad-form` 재사용** — 이미지 업로드/크롭/줌 다 작동

---

## 🎯 갱신 시점

- 의미있는 작업 완료 후 (build bump 단위로)
- 새 이슈 발견 시
- 다음 단계 우선순위 변경 시

다음 작업 시작 전에 이 문서 먼저 읽고, 끝나면 갱신!

---

**현재 줄 (build 282)에서 멈춤 — 다음 컴에서 `git pull` 받고 P1 의 Phase 3.C 교환요청 처리부터 시작!**
