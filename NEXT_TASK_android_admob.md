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

## ✅ 현재 상태 (2026-07-01, build 595) — 여기부터 재개
- ✅ **Phase 1** Capacitor + `android/` 프로젝트 생성, 실기기(삼성 SM-F956Q)에서 **네이티브 실행 성공**(server.url=retwork.jp 로드, 이메일 로그인 OK)
- ✅ **Phase 2** AdMob 리워드 연동 완료 — 실기기에서 **테스트 리워드 영상 시청→영수증 저장 언락 동작 확인**
- ✅ **실 AdMob ID + app-ads.txt** 반영 (아래 키값). 단 `_ADMOB_TESTING=true` 유지 → **출시 시 false 로**
- ✅ **서명 AAB 빌드 완료**: `android/app/release/app-release.aab` (8.4MB)
- ✅ **Google Play 개발자 계정 생성**(개인, $25 결제 완료). 계정 ID `6744529180288496834`
- 🔴 **BLOCKED: Google 신원 확인 중(며칠 소요)** → 확인 완료 이메일(minwoo.seo1019@gmail.com) 와야 **「앱 만들기」 잠금 해제**. 그전까진 앱 등록 불가.

### 🔑 키값 (교체·검증용)
| 항목 | 값 |
|---|---|
| 패키지 ID(appId) | `jp.retwork.app` (변경 불가) |
| AdMob **App ID** (Manifest) | `ca-app-pub-6495876616577319~1957083064` |
| AdMob **보상형 광고단위** | `ca-app-pub-6495876616577319/1298194826` |
| 퍼블리셔(app-ads.txt, =AdSense와 동일) | `pub-6495876616577319` |
| 업로드 키스토어 | `C:\Users\minus\retwork-upload.jks` · alias `upload` · **비번 백업 필수(잃으면 업데이트 불가)** |
| 리워드 코드 위치 | `public/index.html` `_ADMOB_REWARD_ID`/`_ADMOB_TESTING`/`_tryNativeRewarded`/`showAdModal` 분기 |

## ▶ 재개 방법 (신원 확인 완료 이메일 온 뒤)
1. Play Console → **앱 만들기**: 이름 `RetWork レシート家計簿・節約` / 기본언어 **日本語** / **앱** / **무료** / 정책 체크
2. **테스트 → 내부 테스트** 트랙에 `android/app/release/app-release.aab` 업로드
3. **앱 콘텐츠** 선언: 개인정보처리방침 `https://retwork.jp/privacy.html` · 앱 액세스(로그인 필요 → 테스트 계정 제공) · **광고 있음(예)** · 콘텐츠 등급 설문 · 타겟층(성인) · **데이터 안전**(수집: 이메일·영수증 이미지·대략 위치 등 신고) · 금융 특성=해당없음
4. **스토어 등록정보**: 아래 §스토어 문구 + 스크린샷(최소 2장, 폰 캡처) + 아이콘 512² + (선택)피처그래픽 1024×500
5. **심사 제출**(내부테스트 먼저 → 프로덕션). 승인 후:
   - `public/index.html` `_ADMOB_TESTING=false` 로 전환 → 실광고 (push 후 앱 재실행이면 반영, server.url 이라 재빌드 불필요)
   - AdMob 홈 **"앱 스토어 연결"**(Play 리스팅 URL 연결) → 계정 승인·app-ads.txt 검증
6. **웹 게이팅(Phase 5)**: 네이티브 출시 후 비구독자 스캔 등 원가기능 → "앱에서 계속하기" 유도

## 스토어 문구 (일본어, 붙여넣기용)
**짧은 설명(80자):**
`レシートを撮るだけでAIが家計簿を自動作成。近所の最安値マップで賢く節約。`

**전체 설명:**
```
【レシートを撮るだけ、AIが家計簿を自動作成】
RetWork（チリつも）は、買い物レシートを撮影するだけでAIが店舗名・商品名・金額を自動で読み取り、家計簿に記録する無料の節約アプリです。手入力ゼロで続けやすい家計管理を実現します。

「チリも積もれば山となる」——毎日の小さな節約の積み重ねが、年間で大きな差に。RetWorkはその「チリ」を見える化します。

■ 主な機能
・レシートOCRスキャン：撮るだけで自動入力
・カテゴリ別自動分類：食費・外食・日用品など
・月別／年間レポート：支出傾向・予算消化を可視化
・給料日ベースの予算管理：月初でなく給料日から1ヶ月で
・コスパ価格マップ：近所のお店の実際の価格を共有・比較
・商品コスパ検索：同じ商品の最安店をすぐ発見
・PDF／CSV出力：家計データをまるごと保存
・チリつもポイント：使うほど貯まる

■ こんな方に
一人暮らし・主婦・学生・共働き世帯など、食費や日用品を賢く節約したいすべての方に。

日本語・韓国語・英語・中国語対応。基本機能はすべて無料。
今日のレシートが、明日の節約につながります。
```

## 진행 체크리스트
- [x] Phase 1 — Capacitor 추가 + config + 실기기 실행
- [x] Phase 2 — AdMob 리워드 연동 + 실 ID/app-ads.txt (테스트 광고로 동작 확인)
- [x] 서명 AAB 빌드 + Play 개발자 계정 생성($25)
- [ ] **(대기) Google 신원 확인 완료** → 앱 만들기 잠금 해제
- [ ] Play 앱 생성 + AAB 업로드 + 콘텐츠 선언 + 스토어 등록정보 + 심사 제출
- [ ] 승인 후 `_ADMOB_TESTING=false` + AdMob 앱 스토어 연결 (실광고 ON)
- [ ] Phase 5 — 웹 게이팅 ON / iOS 확장(클라우드 빌드)
- [ ] (후속) 소셜 로그인 딥링크 / 네이티브 푸시(FCM)
