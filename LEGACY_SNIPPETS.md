# Legacy Snippets (보존용 — 라이브 코드에서 제거된 옛 로직)

`public/index.html`에서 **제거했지만 참고용으로 남겨두는** 옛 코드 모음.
git 히스토리에도 남아 있지만, 발견성을 위해 여기에 "무엇·왜·관련 잔존"과 함께 기록한다.

---

## 1. 옛 `ov-saveconfirm` 바텀시트 광고 모달 (build 639에서 제거)

**무엇:** 비구독 유저가 영수증 저장 시 띄우던 **바텀시트형 광고 확인 모달**(`#ov-saveconfirm`).
컨텍스트별(chiri / private / menu_photo / monthreport / report_unlock / save) 버튼 라벨 분기 +
광고차단기 폴백(모달 안 뜨면 자동 저장 진행) + AdSense 슬롯(`ad-slot-modal`) 주입 포함.

**왜 제거:** `showAdModal`이 build 335에서 **전체화면 광고 페이지(`openWatchAdPage`, 출석체크 스타일)로 통일**되면서,
이 바텀시트 로직은 `showAdModal` 내 `return;` 뒤의 **죽은 코드**로 남아 있었음 (실행되지 않음).

**관련 잔존(아직 index.html에 있음, 추후 정리 대상):**
HTML `#ov-saveconfirm`(~2351줄), 핸들러 `closeAdModal` / `adComplete` / `adGoPublishChiri` / `adStartFullscreen`.
이 모달이 더 이상 열리지 않으므로 위 핸들러들도 실질적으로 죽은 상태.

```js
// showAdModal() 내부, openWatchAdPage(...) + return; 뒤에 있던 블록:
var el = document.getElementById('ov-saveconfirm');
if (!el) { console.warn('[ad] ov-saveconfirm 엘리먼트 없음'); if (callback) callback(); return; }
// 부모 stacking context에 갇히지 않도록 body로 이동
if (el.parentElement !== document.body) {
  document.body.appendChild(el);
}
el.classList.add('open');
// ★ 컨텍스트별 버튼 UI 분기
var mainLabel = document.getElementById('confirm-action-label');
var pubBtn    = document.getElementById('confirm-publish-btn');
if (_adContext === 'chiri') {
  if (mainLabel) mainLabel.textContent = t('ad.publish_btn');
  if (pubBtn)    pubBtn.style.display = 'none';
} else if (_adContext === 'private') {
  if (mainLabel) mainLabel.textContent = t('ad.to_private');
  if (pubBtn)    pubBtn.style.display = 'none';
} else if (_adContext === 'menu_photo') {
  if (mainLabel) mainLabel.textContent = '광고 보고 메뉴 사진 등록';
  if (pubBtn)    pubBtn.style.display = 'none';
} else if (_adContext === 'monthreport') {
  // 달력 자세히 보기 (월별 리포트) 진입 광고
  if (mainLabel) mainLabel.textContent = '광고 보고 내용 확인하기';
  if (pubBtn)    pubBtn.style.display = 'none';
} else if (_adContext === 'report_unlock') {
  // 리포트 잠금 해제 광고
  if (mainLabel) mainLabel.textContent = '📊 광고 보고 리포트 펼치기';
  if (pubBtn)    pubBtn.style.display = 'none';
} else {
  if (mainLabel) mainLabel.textContent = t('ad.save_free');
  if (pubBtn) {
    var cat = window._ocrResult && window._ocrResult.cat;
    pubBtn.style.display = (typeof _shouldShowChiriPublish === 'function' && _shouldShowChiriPublish(cat)) ? 'flex' : 'none';
  }
}
// CSS specificity 충돌 우회: 인라인 style로 강제 적용 (!important 포함)
el.style.cssText = 'position:fixed !important;inset:0 !important;z-index:99999 !important;background:rgba(0,0,0,0.7) !important;display:flex !important;align-items:flex-end !important;justify-content:center !important;backdrop-filter:blur(4px) !important;';

// Fallback: 광고 차단기 등으로 모달이 화면에 안 뜨면 자동으로 저장 진행
setTimeout(function() {
  if (!_adCallback) return; // 이미 처리됨
  var r = el.getBoundingClientRect();
  var visible = r.width > 0 && r.height > 0 && getComputedStyle(el).display !== 'none';
  if (!visible) {
    console.warn('[ad] 모달 표시 실패 (광고 차단기 의심) → 광고 스킵, 저장 진행');
    el.classList.remove('open');
    el.style.cssText = '';
    var cb = _adCallback;
    _adCallback = null;
    cb();
  }
}, 600);

// AdSense 승인 후 실제 광고 주입 (플레이스홀더 대체)
setTimeout(function() {
  if (_injectAd('ad-slot-modal', 'modal', _adContext)) {
    var ph = document.getElementById('ad-placeholder-modal');
    if (ph) ph.style.display = 'none';
  }
}, 200);
```

---

## 2. 미사용 전역 함수 25개 (build 640에서 제거)

전부 **정의만 있고 호출·onclick·문자열 참조가 전혀 없던** 함수(검증: 각 이름 등장 1회).
현재 어떤 기능과도 연결 안 됨 → 제거. 전체 코드는 **git 히스토리**(제거 직전 커밋)에 있음:
`git show 2728a80:public/index.html` 로 복원 가능.

| 함수 | 비고 |
|---|---|
| `ctStoreExchange` / `ctWatchAd` | 레거시 치리 교환·광고시청 (RPC/새 흐름으로 대체) |
| `scrollToStoreCard` | 맵 InfoWindow→카드 스크롤 (주석에 "Legacy 미사용") |
| `_globalToneFix` / `_localContrast` / `_unsharpMask` | 영수증 전처리(CLAHE/unsharp) — 전처리 개편으로 미사용 |
| `buildStoreInfoContent` (99줄) | 옛 맵 마커 말풍선 빌더 (현재 바텀시트로 대체) |
| `openMonthDetail` (98줄) | 옛 월 상세 뷰 |
| `openShopDetail` / `openPlaceEmbed` / `_sdRenderGmaps` | 옛 가게/장소 상세·구글맵 |
| `getDemoResult` | API키 없을 때 데모결과 (백엔드 키 상시 → 미사용) |
| `filterHistory` / `goToCatHistory` | 옛 내역 필터·카테고리 이동 |
| `cpSelectStar` / `toggleCpItem` | 옛 치리 공개모달 별점·항목 토글 |
| `toggleInfoExpand` / `closeCatWheel` / `ctStartNoticeSlide` | 기타 UI 헬퍼 |
| `_handleUserBannedError` / `showOnboarding` | 미연결 에러핸들러·온보딩 |
| `_catLabel` / `_fmtMins` / `_admPcBackToUserList` | 트리비얼 미사용 헬퍼 |
| `_radarDummyData` | 빈 레거시 배열 |

---

## 3. 옛 `ov-saveconfirm` 세트 — HTML 모달 + 핸들러 4개 (build 642에서 제거)

§1에서 제거한 바텀시트 로직의 **나머지 껍데기**. 모달이 더 이상 열리지 않아 전부 고아 상태였음.

**제거 대상 (전체 코드는 git `320122c:public/index.html` 복원 가능):**
- **HTML `#ov-saveconfirm`** (약 76줄): 저장 시 뜨던 바텀시트. 가짜 광고 목업(🏰⚔️ Strategy Game, 👍👎🔇⏸, `広告` 배지, `💰500`, インストール 버튼) + 액션/치리공개 버튼 + 프리미엄 업셀. 내부 ID `ad-slot-modal`/`ad-placeholder-modal`/`confirm-action-btn`/`confirm-action-label`/`confirm-publish-btn`.
- **핸들러 4개**: `closeAdModal`(닫기), `adStartFullscreen`("광고보고 저장"→ctOpenFullscreenAd), `adGoPublishChiri`("광고보고 치리공개"→saveAndPublishChiri), `adComplete`(하위호환 스텁, 호출처 없음).

**왜 안전:** 활성 "저장 시 광고" 흐름은 `showAdModal`→`openWatchAdPage`→`ctOpenFullscreenAd`(전부 유지). 이 세트는 서로만 참조, 활성 코드 참조 0. CSS(`.confirm-overlay` 등)는 31717줄 셀렉터가 클래스명 참조해 **그대로 둠**(무해한 죽은 스타일).
