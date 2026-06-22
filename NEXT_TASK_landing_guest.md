# 🔴 최우선 작업 — 애드센스 대응: 보이는 랜딩 + 게스트 모드

> **다른 PC에서 이어서 시작하면 이 파일을 먼저 읽을 것.** (몰/층 작업 `NEXT_TASK_mall_floor.md` 보다 우선 — 애드센스 수익화 차단 이슈)
> 작성: 2026-06-18 (build 538 시점) · 상태: **미착수(설계 확정)**

---

## 0. 왜 (배경)
- **AdSense 거절** (retwork.jp, 2026-06-18): "가치 없는 콘텐츠" + **웹마스터 품질 가이드라인 위반**.
- 원인 2가지:
  1. **클로킹** — 알찬 소개글이 `#seo-landing`(index.html ~965행)에 `position:absolute;left:-9999px;aria-hidden="true"`로 **화면 밖에 숨겨져** 크롤러에게만 보임 = 은닉 텍스트.
  2. **빈약** — 사람·크롤러가 실제로 보는 건 온보딩 슬라이드 + 로그인 폼뿐. 읽을 콘텐츠 없음.
- 거절은 **가입 흐름이 아니라 "크롤러가 URL에서 읽는 콘텐츠"** 문제. 게스트 모드만으론 해결 안 됨 → **보이는 랜딩이 필수**.
- 이미 OK인 것: `privacy/terms/contact/about.html` 존재(필수요건 충족), 블로그 10편(`public/blog/`).

## 1. 최종 설계 (사용자 확정)
```
첫 진입(비로그인) → [랜딩: 소개·기능·사용법·절약팁·FAQ·푸터]
        ├─ ✕ 닫기        → 바로 게스트 앱
        ├─ [ゲストで試す]  → 게스트 앱 (탐색 OK · 저장 ✕ → 저장 시 가입 유도)
        └─ [ログイン/会員登録] → 기존 로그인 → 일반 앱
```
- 기존 **온보딩 4슬라이드(`#screen-onboarding`)는 랜딩으로 대체**(제거 또는 미사용).
- 게스트 = 일반 유저처럼 앱 탐색 가능, **저장(쓰기)만 불가**.
- 언어: AGENTS 규칙상 **SEO 랜딩 = 일본어 고정**(4개국어 불필요). 단 게스트 모드 앱 내부 UI 문구(배너·가입유도 토스트)는 4개국어.

## 2. 현재 코드 사실 (스캔 완료 — 착수 전 확인됨)
### 부팅 (index.html ~29281 IIFE)
```js
if (!localStorage.getItem('receiptiq_onboarded')) { showOnboarding(); return; }   // 18353
var res = await _sb.auth.getSession();
if (res.data && res.data.session) { _currentUser = res.data.session.user; showApp(); }  // 18729
else { document.getElementById('screen-auth').style.display = 'flex'; }
```
- 화면: `#screen-onboarding`(1055) / `#screen-auth`(1097) / `#screen-main`(앱) / `#app`(1052) / `#seo-landing`(965, 숨김).
- `_currentUser` 전역: 17142 선언, 29289·29307에서 세팅. `onAuthStateChange` 29302.
- `showOnboarding()` 18353, `onbSkipToAuth()` 18377(`receiptiq_onboarded='1'`).
- **standalone 감지 기존재**: `window.matchMedia('(display-mode: standalone)').matches || navigator.standalone` (19017, 29233 등).
- **기존 게스트 개념 없음**. 현재 앱은 로그인해야 `#screen-main` 도달.

### ★ 좋은 소식: 대부분의 쓰기는 이미 로그인 가드 있음
앱의 ~50개 Supabase 쓰기 대부분이 `if (!_currentUser) { ...return; }` (또는 `if(_currentUser){...}`) 패턴 → **게스트(`_currentUser=null`)는 자동 차단**. 토스트 키 `toast.login_required` 재사용 가능.
- 가드 패턴 예: 5928(출석), 6432(교환), 7508(치리톡 글/댓글), 8147(별점), 11470(비공개메모), 18242(프로필), 20764(신고), 28571(메뉴 좋아요).

### ⚠️ 진짜 막아야 할 곳 (가드 없이 로컬 저장되는 경로)
- **`saveManualEntry()` 9215** + **`saveOcrResult()` 13078**: Supabase 부분은 `if(_currentUser)` 가드지만, **로컬 DB(`DB` 배열/localStorage) 저장은 로그인 없이도 실행됨** → 게스트면 여기서 **저장 자체를 막고 가입 유도** 필요.
- 로컬 영수증 저장/영속 함수 경로 확인 후 게스트 분기 추가.

### ⚠️ null 유저 견디기 (크래시 방지)
- `showApp()`(18729) 및 그 데이터 로드가 `_currentUser.id`를 가드 없이 읽으면 게스트에서 크래시. **showApp + 모든 `_currentUser.id` 직접 참조** 감사 필요(가드 추가/빈 상태 렌더).

### i18n 4블록 시작 (대략): ja 13803 · ko ~14136 · en ~14500 · zh ~14760. 앵커 `'mr.title'`.

## 3. 구현 계획 (2 Phase)

### ✅ Phase 1 — 보이는 랜딩 (애드센스 해결 · 저위험 · 먼저 배포)
1. `#seo-landing` 콘텐츠를 **보이는 `#screen-landing`** 으로 전환: `left:-9999px`/`aria-hidden` 제거, 히어로 + 기능/사용법/팁/FAQ + 푸터를 정상 노출. 우상단 **✕ 닫기**, 하단(또는 히어로) **[ゲストで試す]** · **[ログイン / 会員登録]** 2버튼.
2. **부팅 라우팅 재작성**(29281):
   - 세션 있음 → `showApp()`(일반).
   - 세션 없음 + **standalone(설치앱)** → 게스트 앱 바로(또는 auth) — 설치 유저는 마케팅 랜딩 skip.
   - 세션 없음 + 브라우저 → **`#screen-landing` 노출**.
   - `receiptiq_onboarded` 로직은 랜딩 노출 여부로 대체/정리(✕·게스트 진입 시 `rw_landing_seen` 등).
3. 버튼 동작: [로그인]→기존 `#screen-auth`. [게스트로 시작]/✕→(Phase 2 전까지는 임시로 `#screen-auth` 또는 게스트 stub). **Phase 1 단독 배포 시엔 게스트 버튼이 일단 로그인으로 가도 됨**(랜딩 공개 자체가 애드센스 해결).
4. `aria-hidden` 제거로 보이는 콘텐츠 = 크롤러 콘텐츠(클로킹 해소). 빌드번호 2곳↑, 문법검사, push.
5. **재신청**: 실제 배포·색인 후 AdSense "검토 요청". (숨긴 텍스트 완전 제거 확인 후에만)

### Phase 2 — 게스트 모드 (UX · 신중)
1. 전역 `_guestMode` 플래그. [게스트로 시작]/✕ → `_guestMode=true; showApp()`.
2. **`showApp()` + 데이터 로드 null 유저 하드닝**: `_currentUser` 없을 때 빈/샘플 상태 렌더, `_currentUser.id` 참조 전부 가드.
3. **로컬 영수증 저장 차단**: `saveManualEntry`/`saveOcrResult` 진입부에 `if(_guestMode){ openAuthForSignup(); return; }` (저장 시 가입 유도 모달/토스트).
4. **게스트 배너**: 앱 상단/홈에 "게스트 탐색 중 · 가입하면 저장돼요 [가입]" 고정 CTA.
5. 기존 `toast.login_required` 자리들을 게스트용 친절 문구(가입 유도)로 다듬기(선택).
6. 공개 읽기(치리맵·product_prices·price_pins RLS read=true) → 게스트 탐색 OK 확인.
7. i18n: `guest.banner`·`guest.save_signup`·`landing.cta_guest`·`landing.cta_login` 등 4개국어(랜딩 본문은 일본어 고정).

## 4. 작업 규칙
- `main` 직접 push. 빌드번호 2곳(`window.__APP_BUILD__`, sw.js `CACHE_NAME`) 동반 ↑.
- 커밋 전 문법검사:
  ```bash
  node -e "const fs=require('fs');const h=fs.readFileSync('public/index.html','utf8');const m=h.match(/<script>([\s\S]*?)<\/script>/g)||[];let bad=0;m.forEach((s,i)=>{const b=s.replace(/^<script>/,'').replace(/<\/script>$/,'');try{new Function(b)}catch(e){bad++;console.log('SCRIPT#'+i,e.message.split('\n')[0])}});console.log(bad?'ERR '+bad:'OK '+m.length)"
  ```
- Phase 1 먼저 배포 → 애드센스 재신청 → Phase 2 진행.

## 5. 한계 / 메모
- Phase 1(랜딩)은 **명백한 위반 제거 + 콘텐츠 공개**라 필수지만, AdSense는 콘텐츠 깊이도 봄 → **블로그 보강**(15~25편)이 안정적 통과의 보완책. 
- 데모(두 안 비교)는 채택 = "온보딩 슬라이드 → 게스트+랜딩 대체" 안.
