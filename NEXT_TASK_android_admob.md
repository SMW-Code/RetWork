# NEXT_TASK — 안드로이드 네이티브 래핑 + AdMob 리워드 광고

> **목표:** PWA(retwork.jp)를 Capacitor로 안드로이드 앱으로 감싸 **AdMob 리워드 광고**를 붙인다.
> "광고 시청 완료 → 영수증 저장 언락" 구조로 **스캔 원가(Vision+GPT)를 광고 수익으로 상쇄**.
> **환경:** Windows · 비개발자 · **Mac 불필요**. 실제 실행은 이 문서를 보고 단계대로.
> ⚠️ 왜 TWA 아니라 Capacitor? → **TWA(단순 웹뷰)는 AdMob 못 씀.** 네이티브 SDK 접근하려면 Capacitor.

---

## 0. 전략 요약
- Capacitor 껍데기가 **`https://retwork.jp` 를 그대로 로드**(`server.url`) + 네이티브 브리지로 AdMob 호출.
  → 웹 코드 거의 그대로, **웹 배포만 하면 앱에도 즉시 반영**(앱 재심사 불필요, 네이티브 플러그인 바뀔 때만 앱 업데이트).
- 같은 `public/index.html` 이 분기: **웹 = 기존 게이팅/데모, 앱 = AdMob 리워드**. 판정 = `window.Capacitor?.isNativePlatform()`.
- ⚠️ 이 앱은 **번들러 없는 단일 파일(plain `<script>`)** 이라, 네이티브에선 플러그인을 **`window.Capacitor.Plugins.AdMob`** 로 접근한다(‎import 아님).

## 1. 준비물 & 비용 (전부 Windows 가능)
| 항목 | 비용 | 비고 |
|---|---|---|
| Node.js | 무료 | 이미 사용 중 |
| Android Studio | 무료 | Windows 설치 OK(JDK/SDK 포함) |
| Google Play 개발자 계정 | **$25(1회)** | play.google.com/console |
| AdMob 계정 | 무료 | admob.google.com → 앱 등록 → **리워드 광고 단위** 발급 |
| 앱 아이콘/스플래시 | — | 512·1024 아이콘 등 |
| 개인정보처리방침 URL | — | `https://retwork.jp/privacy.html` (있음) |

→ **시작 총비용 ≈ $25.**

---

## 2. Phase 1 — Capacitor 추가 (기존 repo에서, Windows 터미널)
```bash
cd C:\Users\minus\Desktop\receiptiq
npm i @capacitor/core @capacitor/cli @capacitor/android @capacitor-community/admob
npx cap init "RetWork" "jp.retwork.app" --web-dir=public
npx cap add android
```
- 앱 이름 `RetWork`, 패키지ID `jp.retwork.app`(고정 — 나중에 못 바꿈, 신중히).
- `--web-dir=public` 은 형식상 필요(실제론 server.url로 원격 로드).

**`capacitor.config.ts`** (init 후 아래로 교체):
```ts
import type { CapacitorConfig } from '@capacitor/cli';
const config: CapacitorConfig = {
  appId: 'jp.retwork.app',
  appName: 'RetWork',
  webDir: 'public',
  server: {
    url: 'https://retwork.jp',   // 라이브 사이트를 앱 안에서 로드
    cleartext: false
  }
};
export default config;
```

## 3. Phase 2 — AdMob 연동

### (a) AdMob 콘솔에서 발급받을 것
- **App ID**: `ca-app-pub-XXXXXXXX~XXXXXXXX`
- **리워드 광고 단위 ID**: `ca-app-pub-XXXXXXXX/XXXXXXXX`
- (테스트용은 구글 공식 테스트 ID 사용 — 개발 중엔 반드시 테스트 ID로)

### (b) `android/app/src/main/AndroidManifest.xml` — `<application>` 안에 추가
```xml
<meta-data
  android:name="com.google.android.gms.ads.APPLICATION_ID"
  android:value="ca-app-pub-XXXXXXXX~XXXXXXXX"/>
```

### (c) `public/app-ads.txt` 추가 (AdMob 수익 인증에 필수!)
`https://retwork.jp/app-ads.txt` 로 서빙되어야 함. 내용(AdMob이 알려주는 본인 퍼블리셔 값):
```
google.com, pub-XXXXXXXXXXXXXXXX, DIRECT, f08c47fec0942fa0
```
> ⚠️ 실제 퍼블리셔 ID 받은 뒤 추가. 안 넣으면 광고 수익 인식 안 됨.

### (d) `public/index.html` — 리워드 광고 분기 (Claude가 작성)
- 네이티브면 기존 "가짜 광고 시청" 자리에서 **AdMob 리워드**를 띄우고, **보상 완료 콜백에서 영수증 저장 언락**. 웹이면 기존 동작 유지.
- 대략 이런 헬퍼(플러그인 버전별 메서드/이벤트명은 설치 시점에 확정):
```js
async function _showRewardedAd(){
  var C = window.Capacitor;
  if(!(C && C.isNativePlatform && C.isNativePlatform() && C.Plugins && C.Plugins.AdMob)) return null; // 웹 → null(기존 흐름)
  var AdMob = C.Plugins.AdMob;
  try{
    await AdMob.prepareRewardVideoAd({ adId: 'ca-app-pub-XXXX/REWARD_UNIT' });
    var got = await new Promise(function(res){
      var rewarded=false;
      AdMob.addListener('onRewardedVideoAdReward',   function(){ rewarded=true; });
      AdMob.addListener('onRewardedVideoAdDismissed',function(){ res(rewarded); });
      AdMob.showRewardVideoAd();
    });
    return got===true;   // true=보상획득 → 저장 언락
  }catch(e){ console.warn('[admob]',e); return false; }
}
```
- 연동 지점: 현재 "광고 보고 저장"(showAdModal/`_getWatchAdOptsByContext` 경로)에서 네이티브면 `_showRewardedAd()` 사용하도록 교체.

## 4. Phase 3 — 빌드·테스트 (Android Studio, Windows)
```bash
npx cap sync android
npx cap open android
```
- Android Studio에서 에뮬레이터/실기기 실행.
- **AdMob 테스트 광고 단위**로 "시청→보상→저장 언락" 동작 확인.

## 5. Phase 4 — Google Play 출시
1. Android Studio: **서명키 생성 → AAB 빌드**.
2. Play Console: 앱 생성 → 스토어 등록정보(아이콘·스크린샷·설명) → 콘텐츠 등급 → **데이터 안전(수집 항목 신고)** → 개인정보 URL.
3. **내부 테스트** 트랙 먼저 → 문제없으면 **프로덕션 심사** 제출.
4. 승인 후 **AdMob 실광고 단위로 교체** + app-ads.txt 실값 확인.

## 6. Phase 5 — 이후
- 웹 비구독자 **"앱에서 계속하기" 게이팅** ON (스캔 등 원가 기능 → 스토어 유도).
- **iOS**: Mac 없이 **클라우드 빌드**(Ionic Appflow / Codemagic) + Apple Developer **$99/년**. Capacitor는 iOS도 지원하므로 같은 코드로 확장.

---

## ⚠️ 함정 체크리스트
- [ ] **app-ads.txt** (retwork.jp/app-ads.txt) — 없으면 AdMob 수익 미인식.
- [ ] **테스트 광고 ID로만 개발** — 본인 실광고 클릭하면 계정 정지 위험.
- [ ] **UMP 동의 폼**(개인화 광고 동의) — 권장.
- [ ] **최소 기능성** — Play는 "그냥 웹 로드"만이면 깐깐. 카메라·푸시·AdMob 등 네이티브 가치로 통과.
- [ ] **구독 결제** — 안드로이드 디지털 구독은 **Google Play 결제 강제**(수수료). 가격 설계 반영.
- [ ] server.url 방식이라 **오프라인 시 빈 화면** — 필요하면 오프라인 폴백 고려.
- [ ] 패키지ID(`jp.retwork.app`)는 **출시 후 변경 불가**.

## 역할 분담
- **Claude**: capacitor.config.ts, AndroidManifest 스니펫, app-ads.txt 내용, `index.html` 리워드 분기 코드, 명령어·클릭 순서 안내.
- **민우**: Android Studio 설치, Play/AdMob 계정 생성 및 ID 발급, 터미널 명령 실행, 스토어 제출.

## 🐞 알려진 이슈 (네이티브 앱)
- **푸시 알림 = 네이티브에서 미지원** — 앱 설정에서 "이 브라우저는 지원 안 함". RetWork 푸시는 Web Push(브라우저 API)라 Capacitor WebView에선 안 됨. 웹(Chrome/PWA)은 정상.
  - 해결: **FCM(Firebase) + `@capacitor/push-notifications`** → Firebase 프로젝트 + google-services.json + 디바이스 토큰 Supabase 저장 + 서버 크론(log-reminder/price-watch)이 네이티브엔 FCM 발송(웹은 web-push 유지).
  - 우선순위: 낮음(리텐션 부가기능). Play 출시·AdMob 이후 후속 작업.
- **소셜 로그인(Google/LINE/Apple) 딥링크** — 네이티브 WebView에서 OAuth가 외부 브라우저(Chrome)로 나갔다가 **앱으로 안 돌아옴**(세션이 Chrome에 생김). 이메일 로그인은 정상.
  - 해결: 커스텀 스킴(`jp.retwork.app://login-callback`)을 Supabase OAuth redirect 로 등록 + AndroidManifest intent-filter + `App.addListener('appUrlOpen')` 로 토큰 받아 `supabase.auth` 세션 설정. (또는 네이티브 Google 로그인 플러그인 + `signInWithIdToken`)
  - 우선순위: 낮음(이메일 로그인으로 대체 가능). AdMob 이후 처리.

## 진행 상황 (b594 시점)
- ✅ Phase 1: Capacitor + android 프로젝트 생성, 실기기(SM-F956Q)에서 네이티브 실행 성공(retwork.jp 로드)
- 🔄 Phase 2: `index.html`에 AdMob 리워드 분기 코드 추가(테스트 광고 ID). **AdMob 실계정 발급 후** `_ADMOB_REWARD_ID`+`_ADMOB_TESTING=false`+Manifest App ID 교체 필요.

## 진행 체크리스트
- [ ] Phase 1 — Capacitor 추가 + config
- [ ] Phase 2 — AdMob 계정·ID 발급 + Manifest/app-ads.txt + index.html 분기
- [ ] Phase 3 — 로컬 빌드·테스트(테스트 광고)
- [ ] Phase 4 — Play 심사·출시(실광고 교체)
- [ ] Phase 5 — 웹 게이팅 ON / iOS 확장
