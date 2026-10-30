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
