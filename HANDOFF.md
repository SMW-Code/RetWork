# 🔄 RetWork (チリつも) — 인수인계 문서

> **최종 갱신**: 2026-06-03 / build 317 / v0.9.0
> 다른 컴퓨터에서 이어 작업할 때 이 파일부터 읽으세요.

---

## 📌 프로젝트 개요

- **서비스명**: RetWork (チリつも)
- **타겟 시장**: 일본 (영수증 OCR + AI 가계부 + 절약 커뮤니티 PWA)
- **배포 URL**: https://retwork.jp (Vercel 자동 배포)
- **GitHub**: SMW-Code/RetWork (`main` 브랜치 → Vercel 자동 빌드)
- **로컬 경로**: `C:\Users\minus\Desktop\receiptiq`
- **구조**: 단일 파일 PWA — `public/index.html` (~20,800+ 줄) + `public/sw.js`
- **백엔드**: Supabase (`fkvfbxfgidrvymoftkdd.supabase.co`)
- **현재 버전**: `v0.9.0` (semantic) / `build 317` (internal)
- **본인용 TWA APK**: PWA Builder 로 빌드된 별도 Android 앱 (assetlinks.json 등록됨, jp.retwork.app)

---

## 🆕 build 301 → 317 미니 변경 로그

### build 301 — 홈 → 내역 이동 글리치 + 디버그 로그
- `goToHistoryEntry(cat, id)`: switchTab 호출 전에 `currentFilter`/`_currentCatFilter` 미리 cat 으로 설정 → 첫 렌더부터 5월+cat 정확히 표시
- console.log 디버그 — 정식 출시 직전 일괄 정리 예정

### build 302 — 친구 초대 카드 4개 언어 번역
- `inv.*` 12개 i18n 키 + 어드민 언어시트 카테고리

### build 303 — 가성비맵/치리톡맵 race condition
- `_mapUserInteracted` 플래그 + `dragstart`/`zoom_changed` 리스너 + 가게 panTo 시 명시 set

### build 304 — 어드민 → 유저 쪽지 시스템 Phase 1
- `admin_messages.sql` 신규 (제목/본문/우선순위/링크/만료)
- 4 RPC: admin_send_message / admin_broadcast_message / get_unread_admin_messages_count / mark_admin_message_read
- 어드민 사용자 상세에 "✉️ 쪽지 보내기" + 발송 모달
- 사용자 받은쪽지함 모달 (`ov-user-inbox`) + 우선순위 배지

### build 305 — 헤더 아바타 빨간 배지 + realtime
- 모든 화면 `.hdr-avatar` 7곳에 펄스 빨간 배지 (`data-badge::after`)
- Supabase realtime 채널 `admin_messages_user_<uid>` 구독
- 최고 우선순위 칩 (🚨/⚠️) 설정창 메뉴에 표시

### build 306 — Web Push 푸시 알림 인프라 Phase A~F
- `push_subscriptions.sql` 테이블 + RLS
- VAPID 키 (서버 + 클라 분리)
- Service Worker push 이벤트 핸들러
- `/api/push` route — Bearer JWT 검증 + 어드민 권한
- 어드민 쪽지/공지 발송 시 자동 푸시 발송
- 설정창 🔔 푸시 알림 토글 + iOS PWA 안내

### build 308 — 헤더 아바타 배지 잘림 fix
- `.hdr-avatar` + `.hdr` overflow:visible
- 배지 위치 top:-8 right:-8 + z-index:10 + pointer-events:none

### build 309~310 — VAPID Public Key 주입 + 헤즈업 강화
- `window.__VAPID_PUBLIC_KEY__` HTML 안 직접 박음
- SW push 옵션: `requireInteraction`(urgent), `renotify`(true), `vibrate`(우선순위별), `urgency:'high'`(VAPID 헤더)

### build 311 — 받은쪽지함 메뉴 가시성 버그
- 어드민 전용 그룹(`id="admin-entry-group"`)에 잘못 넣어서 일반 사용자에게 안 보이던 문제
- 별도 그룹으로 분리

### build 312 — 헤즈업 강화 (rich notification)
- SW: actions 기본 추가 ([확인][닫기]) + timestamp + image option
- notificationclick 에서 'dismiss' 액션 처리

### build 313 — Digital Asset Links (TWA standalone)
- `public/.well-known/assetlinks.json` (sha256 fingerprint)
- `next.config.ts` headers — Content-Type: application/json
- TWA APK 가 진짜 standalone 활성화 → 상단 X 사라짐 + 자체 알림 채널

### build 314 — 댓글/좋아요 푸시 + social type
- `/api/push` 에 `type: 'social'` 권한 분기 추가
  - 일반 사용자도 다른 사용자에게 push 발송 가능
  - 본인 자신에게 발송 금지 (셀프 어뷰져 방지)
  - 1:1 알림만 (다중은 어드민/broadcast 만)
- `_sendSocialPush()` 헬퍼 함수
- 좋아요 (priority:low) / 댓글 (priority:normal) 시 글 작성자에게 자동 푸시

### build 315 — 추가 광고 보상 슬롯 UI 명확화
- 메시지 명확화: `2회 더 받을 수 있어요 · 08–16시 슬롯 (0/2)`
- 슬롯 전환 시 자동 재렌더 (setInterval 30초마다)

### build 316 — 친구 추천 가입 푸시
- `_redeemPendingRef()` 에서 `response.referrer` UUID 받으면 자동 push
- 추천자에게: "🎁 추천 보상이 적립됐어요! · {친구닉네임} 가입"

### build 317 — 출석 슬롯 가능 푸시 (cron)
- `push_attendance_optin.sql` — `push_subscriptions.attendance_optin` 컬럼 추가
- `app/api/cron/attendance/route.ts` — Bearer CRON_SECRET 검증 + 옵트인 사용자 푸시
- `.github/workflows/attendance-push.yml` — UTC 23/7시 (JST 8/16시) cron
- 설정창에 ⏰ 출석 알림 별도 토글 (4개 언어 i18n)
- 환경변수 신규: `CRON_SECRET` (Vercel + GitHub Secrets 양쪽 일치)
- GitHub Secrets: `CRON_SECRET`, `PRODUCTION_URL`

---

## 📨 푸시 알림 시스템 전체 정리 (build 304~317)

### 8가지 푸시 트리거 (현재 작동 중)

| # | 트리거 | type | priority | 발송자 |
|---|---|---|---|---|
| 1 | 어드민 → 유저 쪽지 | admin | 가변 | 어드민 (직접) |
| 2 | 공지 발행 (broadcast) | broadcast | high | 어드민 (직접) |
| 3 | 댓글 받음 | social | normal | 댓글 작성자 (자동) |
| 4 | 좋아요 받음 | social | low | 좋아요 누른 사람 (자동) |
| 5 | 친구 가입 (추천) | social | normal | 가입 친구 (자동) |
| 6 | 출석 슬롯 시작 (JST 8시) | cron | normal | GitHub Actions |
| 7 | 출석 슬롯 시작 (JST 16시) | cron | normal | GitHub Actions |
| 8 | 헤더 아바타 빨간 배지 | in-app | — | Supabase realtime |

### 인프라 아키텍처

```
사용자 클라이언트 (브라우저/PWA/TWA APK)
    ├─ 설정 → 푸시 토글 ON
    │       └─ pushManager.subscribe() → push_subscriptions INSERT
    │
    ├─ 알림 표시
    │   └─ Service Worker push 이벤트 → showNotification (Chrome 사이트 채널)
    │
    └─ in-app 헤더 배지 (Supabase realtime → admin_messages 구독)

서버 (Vercel)
    ├─ /api/push     — 어드민/social/broadcast 발송
    ├─ /api/cron/attendance — GitHub Actions 호출 (Bearer CRON_SECRET)
    └─ web-push 라이브러리 (Node.js)

DB (Supabase)
    ├─ push_subscriptions
    │   - endpoint UNIQUE + p256dh + auth + enabled + attendance_optin
    │   - last_sent_at / last_error 트래킹
    │   - 410/404 만료 시 자동 삭제 (서버에서)
    ├─ admin_messages (Phase 1)
    └─ ct_notifications (in-app, 푸시는 social 헬퍼로 별도 호출)

스케줄러 (GitHub Actions)
    └─ .github/workflows/attendance-push.yml
       - UTC 23시 cron → JST 8시 (오전 슬롯)
       - UTC 7시 cron → JST 16시 (오후 슬롯)
       - workflow_dispatch 수동 트리거 가능
```

### Service Worker 푸시 옵션 (헤즈업 강화)

```js
{
  requireInteraction: priority === 'urgent',  // 닫을 때까지 유지 (Android)
  renotify: true,                              // 항상 새 알림
  vibrate: priority === 'urgent' ? [300,100,...]
        : priority === 'high'   ? [200,100,200]
                                : [150],
  actions: [{action:'open',title:'확인'},{action:'dismiss',title:'닫기'}],
  tag: 'admin-msg-...' / 'social-...' / 'attendance-morning' 등
}
```

### web-push 옵션 (FCM/APNs 우선순위 신호)

```ts
const pushOptions = {
  TTL: 86400,            // 1일 (출석은 28800 = 8시간)
  urgency: 'high'        // VAPID 표준 — OS 가 즉시 헤즈업 표시 유도
};
```

### 알림 헤즈업 (Android Chrome) — 알려진 한계

**Web Push 의 진짜 한계**: PWA/TWA 모두 Chrome 의 사이트 알림 통합 시스템 사용
- 알림 발신자 = Chrome (앱 이름 X)
- 알림 채널 = Chrome 의 사이트별 채널 (`retwork.jp`)
- 헤즈업은 시스템 채널 importance 가 "긴급" 이어야 작동

**해결 방법**: 사용자가 폰 설정에서 채널 importance 변경
- 알림 길게 누르기 → 추가 설정 → 중요도 → "긴급"
- 또는 폰 설정 → 앱 → Chrome → 알림 → 사이트 카테고리

**iOS 16.4+ PWA**: 시스템 통합 잘 되어 있어 헤즈업 정상 작동

---

## 📱 TWA APK 빌드 (build 313 노하우)

### 빌드 도구
**PWA Builder** (https://www.pwabuilder.com/) — 웹 기반, GUI

### 단계
1. https://www.pwabuilder.com/ → `https://retwork.jp` 입력
2. Package For Stores → Android → Google Play 탭
3. 설정:
   - Package ID: `jp.retwork.app`
   - Signing key: **"New"** (자동 생성) ⭐ 반드시 None X
   - Display mode: Standalone
   - Include source code: OFF
4. Download Package → ZIP
5. ZIP 안 `app-release-signed.apk` 만 폰 설치 (aab 는 무시)
6. `signing.keystore` + `signing-key-info.txt` ⭐ 백업 필수

### standalone 활성화 (필수)
- ZIP 안 `assetlinks.json` 내용 확인 (sha256_cert_fingerprints)
- 그 내용을 `public/.well-known/assetlinks.json` 에 저장
- git push → Vercel 배포 → `https://retwork.jp/.well-known/assetlinks.json` 접근 가능
- next.config.ts headers 에 Content-Type: application/json 명시
- TWA APK 재실행 시 Chrome 이 자동 검증 → standalone 활성

### 현재 등록된 SHA-256 (jp.retwork.app)
```
7D:38:51:F4:D8:A1:61:1A:91:84:57:F2:87:AA:B1:44:74:FD:2C:88:EC:25:35:F5:B1:EC:C3:FC:69:ED:B3:91
```

### 정식 출시 시 (Play Store)
- 동일 키스토어 사용해서 재빌드 → 동일 SHA-256 → assetlinks.json 변경 불필요
- Play Console $25 일회성 → AAB 업로드
- 사용자는 Play Store 에서 다운로드 → 자동 업데이트는 그대로 (Web 콘텐츠 fetch 모델)

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
✅ security_patch_v4.sql        (베타 적용 중)
⏳ security_patch_v3.sql         (v1.0.0 직전 재실행)
✅ referral_v2.sql              (추천 보상 pending/광고 청구)
✅ referral_v2_stats.sql        (get_referral_status 통계 확장)
✅ store_edit_requests.sql      (가게 수정요청)
✅ local_ads.sql                (로컬 광고 + bump RPC)
✅ local_ads_px.sql             (width_px/height_px ALTER)
✅ exchange_requests.sql        (치리스토어 교환요청, build 283)
✅ comment_penalties.sql        (댓글 패널티, build 290)
✅ quotes.sql                   (홈 명언 카드 테이블, build 298)
✅ quotes_seed.sql              (정적 명언 48개 시드, build 298)
✅ admin_messages.sql           (어드민→유저 쪽지, build 304)
✅ push_subscriptions.sql       (Web Push 구독, build 306)
✅ push_attendance_optin.sql    (출석 푸시 옵트인, build 317)
```

---

## 🔐 환경변수 (Vercel + GitHub Secrets)

### Vercel 환경변수 (모두 Production 필수)
| Key | 용도 | Sensitive |
|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | 클라/서버 공통 | OFF |
| `SUPABASE_SERVICE_ROLE_KEY` | 서버 admin client | ✅ ON |
| `VAPID_PUBLIC_KEY` | web-push setVapidDetails | OFF |
| `VAPID_PRIVATE_KEY` | web-push setVapidDetails | ✅ ON |
| `VAPID_SUBJECT` | `mailto:admin@retwork.jp` | OFF |
| `CRON_SECRET` | /api/cron/attendance 인증 | ✅ ON |
| `VISION_KEY` | Google Vision API | OFF |
| `OPENAI_API_KEY` | GPT 파싱 (기존) | ✅ ON |

### GitHub Repo Secrets (Actions → Secrets)
| Name | Value |
|---|---|
| `CRON_SECRET` | Vercel 과 **정확히 동일** |
| `PRODUCTION_URL` | `https://retwork.jp` |

### VAPID Public Key 클라 주입
`public/index.html` 상단:
```js
window.__VAPID_PUBLIC_KEY__ = 'BLbeE-rgbHX...';
```
Vercel 의 VAPID_PUBLIC_KEY 와 동일해야 함.

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
