# 🔄 RetWork (チリつも) — 인수인계 문서

> **최종 갱신**: 2026-06-02 / build 303 / v0.9.0
> 다른 컴퓨터에서 이어 작업할 때 이 파일부터 읽으세요.

---

## 📌 프로젝트 개요

- **서비스명**: RetWork (チリつも)
- **타겟 시장**: 일본 (영수증 OCR + AI 가계부 + 절약 커뮤니티 PWA)
- **배포 URL**: https://retwork.jp (Vercel 자동 배포)
- **GitHub**: SMW-Code/RetWork (`main` 브랜치 → Vercel 자동 빌드)
- **로컬 경로**: `C:\Users\minus\Desktop\receiptiq`
- **구조**: 단일 파일 PWA — `public/index.html` (~20,500+ 줄) + `public/sw.js`
- **백엔드**: Supabase (`fkvfbxfgidrvymoftkdd.supabase.co`)
- **현재 버전**: `v0.9.0` (semantic) / `build 303` (internal)

---

## 🆕 build 301 → 303 미니 변경 로그

### build 301 — 홈 → 내역 이동 글리치 + 디버그 로그
- `goToHistoryEntry(cat, id)`: switchTab 호출 전에 `currentFilter`/`_currentCatFilter` 미리 cat 으로 설정 → 첫 렌더부터 5월+cat 정확히 표시
- `renderHistory(cat)` 중복 호출 제거
- `console.log('[goToHistoryEntry] id=... date=... → Y/M cat=...')` 디버그 — 정식 출시 직전 일괄 정리 예정

### build 302 — 설정 친구 초대 카드 4개 언어 번역
- 신규 i18n 키 12개 (`inv.*` prefix): title/my_code/copy/stat_friends/stat_earned/stat_pending/desc/share/reward_count/reward_sub_can/reward_sub_capped/reward_btn
- ja/ko/en/zh 전체 번역
- 정적 부분 → `data-i18n` 자동 갱신
- 동적 부분 (reward banner count/sub) → `renderReferralRewardUI` 안에서 `t()` 호출
- 어드민 → 언어시트 → `🎟️ 친구 초대` 카테고리 신규 추가

### build 303 — 가성비맵 race condition 수정
- 증상: 진입 직후 가게 "탭해서 이동하기" 누르면 → 가게 위치 → (몇 초 후) 현 위치로 튕김
- 원인: `initGoogleMap()` 의 `navigator.geolocation.getCurrentPosition` 콜백이 늦게 도착하면서 `_map.setCenter(_mapUserPos)` 가 사용자 panTo 를 덮어씀
- fix: `window._mapUserInteracted` 플래그 + `dragstart`/`zoom_changed` 리스너 + 가게 panTo 호출 시 명시 set + geolocation cb 에서 `if(!_mapUserInteracted) setCenter`
- 치리톡 맵(`_ctMap`) 동일 패턴 fix 도 같이 적용

---

## 🚦 PC 어드민 시스템 (build 268~300) — 가장 큰 변화

### 🎯 6개 톱바
```
RetWork Admin | RetWork(전체) | 게시글 관리 | 언어시트 | 치리관리 | 광고관리 | 테마관리
```

### 📂 사이드바 메뉴 매트릭스

#### 1. RetWork (전체)
- 사용자 (재퍼럴 코드 검색 가능)
- 영수증
- 가게
- 가게핀 → **어드민 전용 화면** (사용자 모달 의존성 제거, build 288~289)
- 가게 수정요청 (배지)
- 공지사항
- 💬 **홈 명언 카드** (build 298 신규)

#### 2. 게시글 관리 (build 290~291)
- 📝 게시글 리스트 (ct_posts + 이미지 + 패널티)
- 💬 댓글 리스트 (ct_comments + store_comments + 패널티)
- 🚨 신고된 댓글
- 🚫 밴 워드 설정

#### 3. 언어시트 (build 281)
- 15개 메뉴 (페이지별 prefix 필터 — `_admI18nLoadWithPrefix`)

#### 4. 치리관리
- 단가/요율
- ✨ **치리 발급 통계** (build 282, customRender)
- 치리스토어 상품
- 📋 **교환요청 처리** (build 283, customRender + exchange_requests)

#### 5. 광고관리
- 📐 **광고 페이지/위치** (16개 AD_POSITIONS + 로컬광고 CRUD, build 275~280)
- 📺 광고 시청 (🎨로컬/📐AdSense **토글** — build 293)

#### 6. 테마관리 (build 294~297)
- 🎨 색상 변수 관리 (라이트/다크 분리, 영역 미리보기, 클릭→점프)

---

### 🔄 드릴다운 네비게이션 (build 286~289)

PC 어드민에서 카드 클릭 시 **모달 X / 콘텐츠 영역 전환 + breadcrumb**:

```
사이드바 [사용자] 클릭
   ↓
사용자 목록 (콘텐츠 영역에 시트 마운트)
   ↓ 카드 클릭
사용자 상세 (콘텐츠 영역 자체가 전환)
   + 상단 breadcrumb [← 사용자 목록]
   ↓ breadcrumb 클릭
사용자 목록 (재마운트)
```

**적용된 카드 5종**:
- 사용자 → `ov-admin-user-detail`
- 영수증 → `ov-admin-edit-receipt`
- 가게 → `ov-admin-edit-store`
- 가게핀 카드 → `_admPcOpenPinStoreView` (어드민 전용 신규 화면)
- 핀 편집 → `ov-admin-edit-pin`
- 스토어 상품 → `ov-admin-item-form`

핵심 헬퍼:
- `_admPcDrilldownTo(modalId, {backMenuKey, backLabel, title})` — 일반화
- `_admPcBackToMenu(menuKey)` — breadcrumb 클릭
- `_admPcMountSheet(modalId, dataLoader)` — 시트를 콘텐츠 영역으로 이동
- `_admPcUnmountAll()` — 시트들을 원래 모달로 복귀
- `_admPcCloseAllAdminModals()` — `.overlay.open` 일괄 닫기 (PC/설정 제외)
- `_isAdminPcActive()` — `ov-admin-pc.style.display === 'flex'` 체크

### 🎨 테마관리 (build 294~297)
- THEME_VAR_GROUPS 5그룹 (배경/표면 · 텍스트 · 테마 색상 · 시스템 색 · 브랜드/특수)
- 영역 미리보기 8종 (헤더/버튼/입력창/알림/평점·칩/영수증 카드 모사/댓글 카드/토글·진행률)
- 미리보기 클릭 → 해당 변수 카드 인디고 펄스 점프
- **라이트/다크 분리 저장**: `_admPcThemeChanges = { light:{}, dark:{} }`
- 모드 전환 시 인라인 setProperty 제거/복원 (다른 모드 영향 X)
- 변경값 복사 → `:root {}` 와 `[data-dark="1"] {}` 블록 분리 출력

### 🎬 광고 페이지/위치 + 로컬 광고 (build 275~280)
- AD_POSITIONS 16개 (홈/영수증/치리맵/치리톡/리워드/출석/추천 페이지 그룹)
- 카드별 "🎨 로컬 광고" 버튼 → 기존 `ov-admin-ad-form` 재사용 (이미지 업로드 + 드래그 크롭 + 줌 + 슬라이더/픽셀)
- 매출 계산 = `AD_POSITIONS.type` 기반 (cpv ¥17 / cpm ¥0.15)
- 클라이언트 표시: `_pickLocalAd(zone, contextOverride)` — 세분화 context 우선, zone 폴백

### 💬 댓글/게시글 패널티 시스템 (build 290)
- comment_penalties 테이블 + 3 RPC (get_active / get_count / admin_grant)
- 패널티 옵션: 1h / 6h / 12h / 1d / 3d / 7d / ⛔ 영구
- 사용자 측 `ctAddComment` 가 활성 패널티 시 토스트 + return
- 카드에 패널티 누적 배지 (블랙유저 전환 참고용)

---

## ⚠️ SQL 파일 — 실행 상태

```
✅ security_patch_v4.sql       (베타 적용 중)
⏳ security_patch_v3.sql        (v1.0.0 직전 재실행)
✅ referral_v2.sql             (추천 보상 pending/광고 청구)
✅ referral_v2_stats.sql       (get_referral_status 통계 확장)
✅ store_edit_requests.sql     (가게 수정요청)
✅ local_ads.sql               (로컬 광고 + bump RPC)
✅ local_ads_px.sql            (width_px/height_px ALTER)
✅ exchange_requests.sql       (치리스토어 교환요청, build 283)
✅ comment_penalties.sql       (댓글 패널티, build 290)
✅ quotes.sql                  (홈 명언 카드 테이블, build 298)
✅ quotes_seed.sql             (정적 명언 48개 시드, build 298)
```

---

## ⚠️ 검증 필요 (배포 완료 but 미확인)

### LINE OAuth
- `line-v2` Custom Provider 사용 (`provider: 'custom:line-v2'`)
- **다음 액션**: Supabase Dashboard → Custom Providers → `line-v2` Edit → Manual configuration:
  ```
  UserInfo: https://api.line.me/oauth2/v2.1/userinfo  ⭐
  ```

---

## 🐛 알려진 이슈

### 1. Supabase Custom OAuth Provider 버그
- 최초 `custom:line` 깨짐 — Dashboard 에서 삭제/수정 불가
- 회피: `line-v2` 재생성 + 클라 코드 `custom:line-v2`

### 2. 자동재생 광고 통계 미수집
- `attendance_auto`, `attendance_modal_auto` 는 HTML 안 SVG placeholder — ad_views 기록 X
- 로컬 광고 등록은 가능 but 실제 표시는 별도 작업 필요

### 3. PWA OAuth 외부 브라우저
- standalone PWA 에서 OAuth 외부 브라우저 열림 — OS 표준
- build 254/256~258 에서 보강 (visibilitychange / `?pwaret=1` URL / 복귀 버튼)

---

## 🔐 Supabase 설정

### Auth Providers
| Provider | 상태 |
|---|---|
| Email | ⚠️ 활성 but 로그인 화면 숨김 (build 259) |
| Google | ✅ 활성 |
| Apple | ❌ "준비 중" 토스트만 |
| LINE (custom:line) | 🚨 깨짐 (사용 X) |
| LINE (custom:line-v2) | ⏳ Manual config 검증 필요 |

### DB Schema 주요 테이블
- `profiles` — referral_code, coin_balance, is_admin, nickname, email
- `receipts` + `items` — 영수증
- `store_comments`, `store_menu_cards`, `price_pins`, `stores`
- `ct_posts` (images 배열 포함), `ct_comments`, `ct_notifications`
- `announcements`, `store_items`, `banned_words`, `banned_users`, `comment_reports`
- `store_edit_requests`, `ad_views`, `coin_transactions`
- `comment_quota_grants`, `referral_rewards`
- `local_ads`, `ad_revenue`
- `exchange_requests` (build 283 신규)
- `comment_penalties` (build 290 신규)
- `quotes` (build 298 신규)

### RPC 함수
- `client_add_coins` / `get_comment_quota_today` / `grant_comment_quota`
- `get_referral_status` (확장: total_referred/total_claimed/total_earned)
- `claim_referral_reward` / `redeem_referral`
- `local_ad_bump(p_id UUID, p_kind TEXT)`
- `get_active_comment_penalty` / `get_user_penalty_count(uid)` / `admin_grant_comment_penalty(uid, hours, reason, related)` (build 290)

### 베타 운영 SQL 상태
- **적용 중**: `security_patch_v4.sql` (코인 한도/쿨다운 우회)
- **v1.0.0 복원**: `security_patch_v3.sql` 재실행

---

## 🎬 광고 시스템 매트릭스

### `_BYPASS_ADS = true` (베타)
| 항목 | 베타 | 정식 |
|---|---|---|
| 광고 모달 표시 | ✓ | ✓ |
| 코인 일일 한도 | ❌ 우회 | ✓ |
| 출석 광고 쿨다운 | ❌ 우회 | ✓ |
| 댓글 1일 5회 한도 | ❌ 우회 | ✓ |
| **댓글 패널티** (build 290) | ✓ 작동 | ✓ |

### 광고 위치 16개 (AD_POSITIONS)
- 풀스크린 9: save / chiri / menu_photo / private / comment_quota / reward / bonus / attendance / referral (¥17/시청)
- 자동재생 2: attendance_auto / attendance_modal_auto (¥0.15/노출, ⚠️ 실제 표시 통합 미완)
- 인라인 5: home / map / store / feed / modal (¥0.15/노출)

### 수익 추정
- 1인 1일 출석 모두 시청: ¥154.80 / ¥12 보상 / ¥142.80 순이익 / 92.2% 마진
- MAU 1만 / 70% / 30일: 월 ¥32,500,000 매출

---

## 🎨 PC 어드민 코드 위치 (Grep 없이 찾기)

| 기능 | 줄번호 (대략) | 함수/요소 |
|---|---|---|
| PC 어드민 HTML | ~2550 | `#ov-admin-pc` |
| `openAdminDashboard` PC 분기 | ~17580 | `window.innerWidth >= 768` |
| `_admPcMenus` 메뉴 정의 | ~17600 | overview/comments/i18n/chiri/ads/theme |
| `_admPcMountSheet` | ~17700 | 시트 마운트 헬퍼 |
| `_admPcCloseAllAdminModals` | ~17680 | 모달 일괄 닫기 |
| AD_POSITIONS | ~17775 | 광고 위치 16개 |
| `_admPcRenderAdPages` | ~17820 | 광고 페이지/위치 |
| `_admPcRenderChiriIssued` | ~18030 | 치리 발급 통계 |
| `_admPcRenderExchangeReqs` | ~18180 | 교환요청 처리 |
| `_admPcRenderCommentList` | ~18280 | 댓글 리스트 + 패널티 |
| `_admPcRenderPostList` | ~18470 | 게시글 리스트 |
| `_admPcRenderQuotes` | ~18630 | 명언 관리 |
| `_admPcRenderThemeManager` | ~18800 | 테마 변수 관리 |
| `_admPcDrilldownTo` | ~17720 | 드릴다운 헬퍼 |
| `_admPcOpenPinStoreView` | ~19450 | 가게핀 어드민 전용 |
| `_admI18nLoadWithPrefix` | ~18450 | i18n prefix 자동 필터 |

---

## 🚀 다음 작업 우선순위

### P0 — 검증
1. **LINE OAuth** Manual config + userinfo URL 확인

### P1 — 정식 출시 (v1.0.0) 직전
2. `_BYPASS_ADS = false` 변경
3. `security_patch_v3.sql` 재실행 (한도 복원)
4. Apple Developer Program 가입 → Apple OAuth 활성화
5. LINE Email Permission 신청
6. AdSense 재심사 신청
7. 자동재생 광고 실제 표시 통합 (`_injectAd` 호출 추가)
8. 푸시 알림 인프라 구축 (절약/주간/가격비교 토글 활성화)

### P2 — 추가 기능
9. 광고 ON/OFF 토글 실제 동작
10. 사용자 측 교환 신청 내역 화면 (현재 어드민만 봄)
11. 교환 취소 시 자동 환불 (현재 수동)
12. 댓글 패널티 해제 UI (현재 만료 자동, 수동 해제 X)
13. TWA (Bubblewrap+Play스토어) 전환

---

## 🛠 개발 명령

```bash
cd C:\Users\minus\Desktop\receiptiq

git add public/index.html public/sw.js
git commit -m "메시지 (build XXX)"
git push
# → Vercel 자동 배포 (1~2분)
```

### Build bump 절차
1. `public/index.html` 의 `window.__APP_BUILD__ = XXX;` 증가
2. `public/sw.js` 의 `const CACHE_NAME = 'receiptiq-v0.9.0-bXXX';` 동일 증가
3. 커밋 메시지 `(build XXX)` 포함

---

## 📂 주요 파일

```
receiptiq/
├── public/
│   ├── index.html       ⭐ 메인 (~20,400+ 줄)
│   ├── sw.js            ⭐ Service Worker
│   ├── about / privacy / terms / contact / sitemap / robots / manifest
│   ├── icons/
│   └── blog/            (10개 글)
├── security_patch_v3.sql     ⏳ v1.0.0 시 재실행
├── security_patch_v4.sql     ✅ 베타 적용 중
├── referral_v2.sql           ✅ 추천 보상
├── referral_v2_stats.sql     ✅ 통계 확장
├── store_edit_requests.sql   ✅
├── local_ads.sql             ✅
├── local_ads_px.sql          ✅
├── exchange_requests.sql     ✅ (build 283)
├── comment_penalties.sql     ✅ (build 290)
├── quotes.sql                ✅ (build 298)
├── quotes_seed.sql           (정적 48개 시드, 1회 실행)
├── HANDOFF.md                ⭐ 이 파일
└── AGENTS.md / CLAUDE.md
```

---

## 🔑 시크릿 위치 (절대 채팅에 붙이지 말 것)

| 자격증명 | 위치 |
|---|---|
| Supabase service_role | Dashboard → Project Settings → API |
| Supabase Anon Key | HTML 내 `_sb` 초기화 (public OK) |
| LINE Channel ID | `2010255617` (공개 OK) |
| LINE Channel Secret | LINE Developers Console |
| Google OAuth | Google Cloud Console |
| Supabase Personal Access Token | https://supabase.com/dashboard/account/tokens |

---

## 📞 디버깅 절차

### PC 어드민 동작 이상
- 콘솔 `openAdminPc()` 직접 호출
- 마운트된 시트: `document.querySelectorAll('[data-original-parent]')`

### 로컬 광고 표시 안 됨
- 콘솔 `_localAdsByZone` 확인
- `_pickLocalAd(slotKey, contextOverride)` 직접 호출

### 드릴다운 흐름 깨짐
- breadcrumb 잔존: `document.getElementById('apc-breadcrumb')`
- innerHTML 직접 주입 함수 (예: `_admPcOpenPinStoreView`) 는 시작부에 `_admPcUnmountAll()` 호출 필수

### 테마 변수 변경 후 모드 전환 시 색 섞임
- `_admPcThemeChanges` 가 `{light:{}, dark:{}}` 구조인지 확인
- `_admPcThemeSetDark` 가 이전 모드 removeProperty 호출하는지

---

## 🔥 절대 잊으면 안 되는 것

1. **단일 HTML 파일** (`public/index.html`) = 전부
2. **Build bump 안 하면 새 버전 못 봄** — sw.js + index.html 둘 다
3. **`_BYPASS_ADS = true` 베타용** — v1.0.0 직전 `false` + SQL v3 재실행
4. **emoji 는 사용자 명시 요청 시만**
5. **사용자(minwoo) 한국인** — 한국어 응답, UI 일본어
6. **PC 어드민 진입 임계값 768px** (DevTools 열어도 OK)
7. **상세 모달 z-index 10001** (PC 어드민 9500 위)
8. **`innerHTML` 직접 주입 화면은 시작부에 `_admPcUnmountAll()` 호출 필수** (시트 손실 방지)
9. **테마 변수 변경은 light/dark 분리 저장** — 단일 namespace 함정 주의

---

## 🎯 갱신 시점
- 의미있는 작업 완료 후
- 새 이슈 발견 시
- 우선순위 변경 시

다음 작업 전 이 문서 먼저 읽고, 끝나면 갱신!

---

**현재 build 300 / 6개 톱바 / PC 어드민 풀스크린 / 드릴다운 / 11개 SQL 파일**
**다음 컴 인계 시 P0 (LINE OAuth) → P1 (v1.0.0 출시 준비) 순으로 진행**
