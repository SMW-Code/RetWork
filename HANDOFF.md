# 🔄 RetWork (チリつも) — 인수인계 문서

> **최종 갱신**: 2026-06-01 / build 258 / v0.9.0
> 다른 컴퓨터에서 이어 작업할 때 이 파일부터 읽으세요.

---

## 📌 프로젝트 개요

- **서비스명**: RetWork (チリつも)
- **타겟 시장**: 일본 (영수증 OCR + AI 가계부 + 절약 커뮤니티 PWA)
- **배포 URL**: https://retwork.jp (Vercel 자동 배포)
- **GitHub**: SMW-Code/RetWork (`main` 브랜치 → Vercel 자동 빌드)
- **로컬 경로**: `C:\Users\minus\Desktop\receiptiq`
- **구조**: 단일 파일 PWA — `public/index.html` (~18,900+ 줄) + `public/sw.js`
- **백엔드**: Supabase (`fkvfbxfgidrvymoftkdd.supabase.co`)
- **현재 버전**: `v0.9.0` (semantic) / `build 255` (internal)

---

## 🚦 현재 상태 한눈에

### ✅ 배포 완료 (build 256~258) — PWA OAuth 복귀 동선 개선
PWA에서 LINE/구글 로그인 시 외부 크롬 탭으로 넘어가 인증이 끝나면, 그 탭이 세션만 저장하고
PWA로 복귀시키는 처리. 코드 위치: `authLine`/`authGoogle` + 앱 시작부의 `_isOAuthReturnTab` 분기.

- **build 256**: standalone이면 `localStorage['riq_oauth_from_pwa']='1'` 표식 → 돌아온 크롬 탭이
  `!standalone && access_token && 표식` 감지 → 가림막 스플래시 → `getSession()` 세션 영속화 →
  `window.close()` (커스텀 탭이면 닫히며 PWA 자동 복귀, PWA는 `visibilitychange`로 세션 인식).
- **build 257**: `window.close()`가 막히는 **전체 크롬 탭** 기기 대비 — 0.5초 후 `📱 アプリに戻る`
  버튼(Android `intent://`로 WebAPK 직접 열기) + 안내 표시.
- **build 258**: 복귀 표식을 **URL(`?pwaret=1`)에도** 실어보냄. WebAPK↔크롬이 localStorage를
  공유 안 하는 기기에서 Google 웹 로그인 후 복귀 처리가 안 되던 문제 수정.
  - redirectTo = `origin + '/' + (isStandalone ? '?pwaret=1' : '')`, 감지는 `_hasReturnMark`.

- 📌 **관찰된 동작 차이**: LINE 재로그인은 네이티브 LINE 앱이 딥링크로 앱 직접 복귀(우리 코드 안 거침),
  Google은 순수 크롬 웹 경로라 위 복귀 처리에 의존.
- ⏳ **만약 Google 로그인이 실패 토스트** 뜨면: Supabase → Auth → URL Configuration →
  Redirect URLs에 `https://retwork.jp/**` (와일드카드) 추가 필요.
- 🎯 **정식 출시 시 근본 해결**: TWA(Bubblewrap+Play스토어) 전환하면 커스텀 탭 처리로 자동 복귀 완벽.

- 광고 모달 결과 메시지 분기 (bonus/chiri/menu_photo 등)
- 추가 광고 보상 버튼 disabled 우회 (베타용 `_BYPASS_ADS=true`)
- 댓글 1일 5회 한도 + 광고 모달 시스템 (A안)
- 설정창 레퍼럴 코드 표시 + 복사 버튼
- 로그인 화면 OAuth 버튼: Google ✓ / Apple (준비중 토스트) / LINE
- PWA OAuth 복귀 시 세션 동기화 강화 (`visibilitychange` 리스너)

### ⚠️ 검증 필요 (배포는 완료 but 미확인)
1. **LINE OAuth 정상 작동 여부**
   - `line-v2` Custom Provider 사용 (`provider: 'custom:line-v2'`)
   - 마지막 에러: `error_description=Error+getting+user+profile+from+external+provider`
   - **원인 추정**: LINE의 OIDC discovery 에 `userinfo_endpoint` 누락
   - **다음 액션**: Supabase Dashboard → Custom Providers → `line-v2` Edit →
     **Configuration Method 를 Manual 로 변경**하고 다음 endpoint 직접 입력:
     ```
     Authorization: https://access.line.me/oauth2/v2.1/authorize
     Token:         https://api.line.me/oauth2/v2.1/token
     UserInfo:      https://api.line.me/oauth2/v2.1/userinfo  ⭐
     JWKS:          https://api.line.me/oauth2/v2.1/certs
     Issuer:        https://access.line.me
     ```

---

## 🐛 알려진 이슈 / Workaround

### 1. Supabase Dashboard Custom OAuth Provider 버그
- **증상**: 한 번 만든 `custom:line` provider를 **수정/삭제/비활성화 모두 불가**
- **에러**: `identifier must start with 'custom:' prefix, e.g. 'custom:custom%3Aline'`
- **임시 회피**: `line-v2` 라는 새 identifier로 다시 만들고 클라이언트 코드 동기화 (build 255에서 완료)
- **장기 해결**: Supabase Support 티켓 제출하여 dead provider 강제 삭제 (https://supabase.com/dashboard/support/new)

### 2. 회원가입 400 Bad Request
- 마지막 확인: 사용자가 폰에서 회원가입 시도 시 `signup 400`
- `[signup] code/status/msg` 디버그 로그 추가됨 (build 249)
- **다음 액션**: 새 이메일로 가입 시도 → 콘솔의 `[signup] code: xxx | msg: ...` 확인
  - "Email rate limit exceeded" → 이메일 발송 시간당 4건 한도
  - "Database error saving new user" → `profiles` 자동 생성 trigger 점검
  - "User already registered" → 이미 가입된 이메일

### 3. PWA OAuth 외부 브라우저 분리
- PWA standalone 에서 OAuth 클릭 시 외부 브라우저(기본 브라우저) 열림 — OS 표준 동작
- **build 254에서 보강**:
  - `visibilitychange` 리스너로 PWA 복귀 시 세션 자동 갱신
  - `onAuthStateChange` 강화 (`SIGNED_IN` 외에 `TOKEN_REFRESHED`, `USER_UPDATED`도)
  - URL hash 에 `access_token` 있으면 800ms 후 한 번 더 세션 확인
  - 사용자 안내 토스트: "🔄 外部ブラウザで認証後、自動的に戻ります"

---

## 🔐 Supabase 설정 현황

### Auth Providers
| Provider | 상태 | 비고 |
|---|---|---|
| Email + Password | ✅ 활성 | 이메일 확인 필수 설정인지 점검 필요 |
| Google | ✅ 활성 | `signInWithOAuth({ provider: 'google' })` |
| Apple | ❌ 미설정 | UI는 "🍎 Apple 로그인은 준비 중이에요" 토스트만 |
| **LINE (custom:line)** | 🚨 깨짐 | Dashboard 버그로 삭제 불가, 사용 X |
| **LINE (custom:line-v2)** | ⏳ 검증 중 | Manual configuration 으로 userinfo URL 명시 필요 |

### DB Schema 주요 테이블
- `profiles` — 사용자 프로필 (referral_code, coin_balance, is_admin 등)
- `receipts` + `items` — 영수증
- `store_comments`, `store_menu_cards`, `price_pins` — 가게 정보
- `ct_posts`, `ct_comments`, `ct_notifications` — 치리톡 게시판
- `announcements`, `store_items`, `banned_words`, `banned_users`
- `ad_views`, `coin_transactions` — 광고/적립 통계
- `comment_quota_grants` — 댓글 한도 광고 시청 권한 (build 250에서 신규)

### RPC 함수 주요
- `client_add_coins(amount, type, description)` — 코인 적립 (한도 우회 모드 = `security_patch_v4.sql`)
- `get_comment_quota_today()` — 오늘 댓글 사용량 + 추가 권한 조회
- `grant_comment_quota(p_extra)` — 광고 시청으로 추가 권한 부여 (1 또는 4)

### 베타 운영 중 SQL 패치 상태
- **현재 적용 중**: `security_patch_v4.sql` (코인 적립 일일 한도/쿨다운 제거)
- **정식 출시 전 복원 필요**: `security_patch_v3.sql` 재실행

---

## 🎬 광고 시스템 매트릭스

### `_BYPASS_ADS = true` (베타, build 248~)
| 항목 | 베타 동작 | 정식(v1.0.0) 동작 |
|---|---|---|
| 광고 모달 자체 표시 | ✓ 정상 (UX 검증) | ✓ 정상 |
| 적립 일일 한도 (코인) | ❌ 우회 | ✓ 1일 N회 |
| 출석 광고 쿨다운 | ❌ 우회 | ✓ 슬롯당 2회 |
| 댓글 1일 5회 한도 | ❌ 우회 | ✓ 5회 + 광고로 +1/+4 |

### 광고 종류별 매트릭스
| 위치 | 광고 종류 | 매출 | 사용자 보상 | mode/context |
|---|---|---|---|---|
| 출석 화면 자동재생 | 노출 | ¥0.15 | - | (자동) |
| 출석 완료 모달 자동재생 | 노출 | ¥0.15 | - | `attendance` |
| 출석 완료 동영상 | 시청 | ¥17 | +15치리 | `attendance` |
| 추가 광고 보상 (슬롯당 2회) | 시청 | ¥17 | +15치리 | `bonus` |
| 자발 광고 (리워드 탭) | 시청 | ¥17 | +50치리 | `reward` |
| 가계부 저장 | 시청 | ¥17 | - | `save` |
| 치리 공개 | 시청 | ¥17 | +10치리 | `chiri` |
| 메뉴 사진 등록 | 시청 | ¥17 | +10치리 | `menu_photo` |
| 프라이빗 모드 전환 | 시청 | ¥17 | - | `private` |
| 댓글 한도 광고 | 자동재생+시청 | ¥0.15 + ¥17 | +1회 / +4회 댓글 | `comment_quota` |

### 수익 시뮬레이션
- 1인 1일 출석 모두 시청: **¥154.80 매출 / ¥12 보상 / ¥142.80 순이익 / 92.2% 마진**
- MAU 1만 / 출석률 70% / 30일: **약 ¥32,500,000 매출 (월 약 2,990만엔 순이익)**

---

## 🎨 UI 주요 위치 (Grep 안 하고 바로 찾기)

| 기능 | 줄번호 (대략) | 함수/요소 |
|---|---|---|
| 로그인 화면 | 1020~1080 | OAuth 버튼 (Google/Apple/LINE) |
| 광고 모달 (가계부 저장) | 14306~14400 | `showAdModal`, `adStartFullscreen` |
| 전체화면 광고 | 14405+ | `ctOpenFullscreenAd(mode, callback)` |
| 출석 화면 렌더 | 4200+ | `_ctRenderAttendance` |
| 추가 광고 보상 모달 | 3428~3468 | `ov-att-bonus-ad` |
| 댓글 한도 모달 | 3470~3520 | `ov-comment-quota-ad` |
| ctAddComment | 5416+ | quota 게이트 통합됨 |
| 설정창 | 1952~2060 | `ov-settings` |
| 레퍼럴 코드 UI | 2045+ | `sp-ref-card`, `copyReferralCode` |
| 버전 표시 | 18965 | `__APP_VERSION__`, `__APP_BUILD__` |
| Auth 흐름 | 14633~14750 | `authLogin`, `authSignup`, `authGoogle`, `authApple`, `authLine` |
| onAuthStateChange | 18948+ | 세션 동기화 + UI 갱신 |
| visibilitychange | 18965~ | PWA 복귀 시 세션 재확인 |

---

## 🚀 다음 작업 우선순위

### P0 (지금 해야 할 일)
1. **LINE OAuth 정상 작동 확인**
   - Supabase Dashboard → `line-v2` Edit → **Manual configuration** 전환
   - UserInfo URL: `https://api.line.me/oauth2/v2.1/userinfo` 명시 입력
   - 폰에서 강제 종료 → 재실행 → LINE 로그인 테스트
   - 콘솔에 `[auth] event: SIGNED_IN` 확인 → 메인 화면 자동 전환되면 OK

2. **회원가입 400 에러 정확한 원인 진단**
   - 새 이메일로 가입 시도 → 콘솔의 `[signup] code: ... | msg: ...` 확인
   - 에러 메시지로 원인 매핑 (rate limit / DB trigger / etc.)

### P1 (1~2주 내)
3. **AdSense 재심사 신청**
   - 7개 신규 블로그 글 + 사이트맵 16 URL 등록 완료
   - Search Console에서 충분히 인덱싱된 후 (1~2주) 재심사 요청

4. **출석 광고 흐름 UX 검증**
   - "추가 광고 보상 받기" 버튼 클릭 → 모달 → 광고 → +15치리 흐름 점검

5. **store_comments 일반 댓글 작성 UI**
   - 현재 영수증 공유 시에만 들어감
   - 가게 상세에 별도 댓글 작성 UI 추가 → 같은 quota 체크 통합

### P2 (정식 출시 v1.0.0 전)
6. **Apple Developer Program 가입** ($99/년) → Apple 로그인 활성화
7. **`_BYPASS_ADS = false` 로 변경** + `security_patch_v3.sql` 재실행
8. **모든 광고 한도/쿨다운 시스템 동작 통합 검증**
9. **LINE Email Permission 신청** (LINE Developers Console) → Scope에 `email` 추가
10. **죽은 `custom:line` Provider** Supabase Support 통해 삭제 요청

---

## 🛠 개발 명령

```bash
# 작업 디렉토리
cd C:\Users\minus\Desktop\receiptiq

# 변경 후 배포 (build bump 후)
git add public/index.html public/sw.js
git commit -m "메시지"
git push
# → Vercel 자동 배포 (1~2분)

# 다른 컴에서 처음 클론할 때
git clone https://github.com/SMW-Code/RetWork.git receiptiq
cd receiptiq
git pull
```

### Build bump 절차 (매 push 마다)
1. `public/index.html` 의 `window.__APP_BUILD__ = XXX;` 1 증가
2. `public/sw.js` 의 `const CACHE_NAME = 'receiptiq-v0.9.0-bXXX';` 동일 증가
3. 커밋 메시지에 `(build XXX)` 포함

---

## 🔑 시크릿 / 자격증명 (어디서 확인하나)

⚠️ **절대 채팅이나 코드에 직접 작성하지 말 것**

| 자격증명 | 위치 |
|---|---|
| Supabase service_role key | Supabase Dashboard → Project Settings → API |
| Supabase Anon Key | 코드의 `_sb` 초기화 (HTML 내, public 키라 OK) |
| LINE Channel ID | `2010255617` (공개 OK) |
| LINE Channel Secret | LINE Developers Console (재발급 가능) |
| Google OAuth Client ID/Secret | Google Cloud Console → Supabase Dashboard에 입력됨 |
| Supabase Personal Access Token (CLI/API용) | https://supabase.com/dashboard/account/tokens |
| Apple Developer Key | (미가입 상태) |

---

## 📂 주요 파일

```
receiptiq/
├── public/
│   ├── index.html       ⭐ 메인 파일 (18,900+ 줄, 단일 파일 PWA)
│   ├── sw.js            ⭐ Service Worker (캐시 버전)
│   ├── about.html       사이트 소개
│   ├── privacy.html     개인정보 정책
│   ├── terms.html       이용약관
│   ├── contact.html     연락처
│   ├── sitemap.xml      ⭐ Search Console 등록 (16 URLs)
│   ├── robots.txt
│   ├── manifest.json    PWA Manifest (Blob URL 인라인 처리됨)
│   ├── icons/           앱 아이콘
│   └── blog/
│       ├── index.html   블로그 인덱스 (10개 글)
│       ├── setsuyaku-7tips.html
│       ├── receipt-app-guide.html
│       ├── shufu-food-save.html
│       ├── konbini-super-drug-price.html      ← 신규 (build 244~)
│       ├── gyomu-vs-aeon.html                 ← 신규
│       ├── gakusei-food-20000.html            ← 신규
│       ├── payment-method-compare.html        ← 신규
│       ├── poikatsu-5000.html                 ← 신규
│       ├── fufu-kakeibo.html                  ← 신규
│       └── kakeibo-tsuduku-kotsu.html         ← 신규
├── security_patch_v3.sql   정식 출시 시 재실행할 SQL (코인 한도 복원)
├── security_patch_v4.sql   ⭐ 현재 적용 중 (베타용 한도 우회)
├── HANDOFF.md              ⭐ 이 파일
└── (그 외 docs, AGENTS.md, CLAUDE.md 등)
```

---

## 📞 이슈 발생 시 디버깅 절차

### 1. Vercel 배포 실패
- Vercel Dashboard → Deployments → 최신 실패 로그 확인
- 단일 HTML 파일이라 빌드 단계 거의 없음 — 보통 immediate fail

### 2. Supabase 응답 이상
- Supabase Dashboard → Logs → API/Auth/Database 로그
- RLS 정책 위반 시 보통 `permission denied` 에러

### 3. PWA SW 캐시 문제
- 폰: 앱 강제 종료 → 앱 정보 → 저장공간 → 캐시 삭제 → 재실행
- PC: DevTools → Application → Service Workers → Unregister → Hard Reload

### 4. 광고 모달 / 한도 시스템 디버깅
- 콘솔에서 `_BYPASS_ADS` 값 확인 → 베타엔 `true` 여야 함
- `_sb.rpc('get_comment_quota_today')` 직접 호출로 quota 상태 확인

---

## 🔥 절대 잊으면 안 되는 것

1. **이 단일 HTML 파일 (`public/index.html`) 이 전부야** — React/Vue 아님, 그냥 거대한 vanilla JS
2. **Build bump 안 하면 사용자가 새 버전 못 봄** — sw.js + index.html 둘 다 매번
3. **`_BYPASS_ADS = true` 는 베타용** — 정식 출시 전 반드시 `false` 로 + SQL v3 재실행
4. **emoji는 사용자 명시 요청 있을 때만 추가** (CLAUDE.md 룰)
5. **사용자(minwoo)는 한국인** — 한국어 응답이 기본 (UI는 일본어)

---

## 🎯 이 문서 갱신 시점

- 의미있는 작업 완료 후 (build bump 단위로)
- 새 이슈 발견 시
- 다음 단계 우선순위 변경 시

다음 작업 시작 전에 이 문서 먼저 읽고, 작업 끝나면 갱신!

---

**현재 build 258 배포 — PWA OAuth 복귀 동선 개선(256~258). 실기기 테스트상 대체로 작동, 추가 이상 발견 시 위 "관찰된 동작 차이" 참고하여 이어서 디버깅.**
