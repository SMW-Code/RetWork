# i18n 규칙 — 새 UI는 무조건 4개국어 + 어드민 언어시트 자동 반영

> **이 프로젝트의 강제 규칙.** 앞으로 신설하는 **모든 페이지·카드·모달·바텀시트·토스트·버튼·라벨·placeholder·title** 등 사용자에게 보이는 텍스트는 **처음부터 4개국어(ja/ko/en/zh)로 i18n** 해서 만든다. 하드코딩 금지.
> 키를 `I18N` 사전에 추가하면 **어드민 "언어시트"(i18n CMS)에 자동으로 나타나** 운영자가 나중에 수정할 수 있다(아래 §4).
>
> 대상 파일: `public/index.html` (단일 파일 앱). 빌드 525 기준.

---

## 1. 정책 (무엇을 번역하나)

| 구분 | 언어 처리 |
|---|---|
| **일반 사용자 대면** (홈/스캔/가계부/치리·지도/설정/로그인/모달/토스트 등) | **4개국어 필수** ← 이 문서 대상 |
| **어드민** (`adm*`/`admin*`/`apc*`/`_adm*`, `ov-admin-*`/`ov-apc-*`) | **한국어 고정** (i18n 안 함 — 운영자 전용) |
| **SEO 랜딩/블로그** (`index.html` 상단 마케팅 본문 ~971~1047, 절약·구르메 블로그 검색 노출용) | **일본어 고정** (검색 노출 목적) |

→ 새 UI가 "일반 사용자 대면"이면 **반드시 4개국어**. 어드민/SEO만 예외.

---

## 2. 어떻게 적용하나

### 2-1. 정적 HTML
요소에 `data-i18n` 계열 속성을 단다. 적용은 `applyLang()`이 담당(언어 변경/로드 시 자동).

```html
<div class="sheet-title" data-i18n="foo.title">📍 タイトル</div>
<input placeholder="メモ..." data-i18n-placeholder="foo.memo_ph">
<button title="全画面" data-i18n-title="foo.fullscreen">⛶</button>
```

- 텍스트 → `data-i18n="key"` (값에 `<br>` 등 HTML 있으면 자동으로 innerHTML 처리)
- placeholder → `data-i18n-placeholder="key"`
- title(툴팁) → `data-i18n-title="key"`
- **요소 안에 자식(아이콘 span 등)이 있으면** 컨테이너에 `data-i18n`을 달지 말 것(자식이 날아감). **번역할 텍스트만 `<span data-i18n>`로 감싼다:**
  ```html
  <!-- 나쁨: data-i18n이 <span class=lico>까지 지움 -->
  <div data-i18n="x"><span class="lico"></span> ラベル</div>
  <!-- 좋음 -->
  <div><span class="lico"></span> <span data-i18n="x">ラベル</span></div>
  ```
- 숫자가 가운데 들어가는 라벨은 prefix/suffix를 각각 span으로:
  ```html
  <span data-i18n="att.pre">残り</span><span id="cnt">3</span><span data-i18n="att.per_day">回/日</span>
  ```

### 2-2. 동적 JS (innerHTML/textContent/showToast/placeholder/setAttribute)
`t('key', {params})`로 문자열을 얻어 넣는다. 하드코딩 리터럴 금지.

```js
el.textContent = t('foo.title');
box.innerHTML  = '<div>'+t('foo.body')+'</div>';
showToast(t('foo.saved'));
input.placeholder = t('foo.memo_ph');
el.textContent = t('comm.visitors', { n: count });   // {n} 보간
```

- `t(key, params)`는 값 안의 `{n}`·`{name}` 등을 `params`로 치환한다.
- 카테고리 라벨은 헬퍼 `_cpCatLabel(key)` 사용(ct.cat.* 재사용, 선두 이모지 제거). 활성 표시는 버튼 `data-cat` 속성 비교(SVG 아이콘 비교 금지).

### 2-3. 키를 4개 블록 **모두**에 추가
`var I18N = { ja:{…}, ko:{…}, en:{…}, zh:{…} }` (index.html ~13448). **네 블록 전부**에 같은 키를 추가한다. 한 곳이라도 빠지면 그 언어에서 ja로 폴백되어 일본어가 샌다.

```js
// ja 블록
'foo.title':'タイトル','foo.saved':'✅ 保存しました',
// ko 블록
'foo.title':'제목','foo.saved':'✅ 저장했어요',
// en 블록
'foo.title':'Title','foo.saved':'✅ Saved',
// zh 블록
'foo.title':'标题','foo.saved':'✅ 已保存',
```

---

## 3. 키 네이밍 & 재사용

- 네이밍: `영역.용도` (`chiri.pub_title`, `auth.err_login_bad`, `comm.visitors`, `adc.earned`). 한 영역은 같은 prefix로 묶는다.
- **재사용 먼저**: 같은 의미의 키가 이미 있으면 신설하지 말고 재사용. 자주 쓰는 공통 키:
  - 버튼: `btn.cancel`/`btn.close`/`btn.save`/`btn.confirm`/`btn.ok`/`btn.delete`
  - 포인트 단위: `unit.chiri` (ja チリ / ko 치리 / en·zh Chiri)
  - 광고: `ad.label`/`ad.loading`/`ad.autoplay`/`ad.adsense_note`/`ad.premium_title`/`ad.premium_sub`/`ad.detail`
  - 카테고리: `ct.cat.*` (+ `_cpCatLabel()`), `ct.map.category`
  - 가게/날짜: `ocr.store_unknown`, `hist.month`(`{y}年 {m}月`/en `{mon} {y}`)
- 번역 톤: 한국어는 친근체("~했어요"), 일본어 정중체, 영어 간결, 중국어 간체.

---

## 4. 어드민 "언어시트"(i18n CMS) — 자동 반영됨 ✅

- 어드민 패널 → **언어시트** 탭은 키 목록을 **`Object.keys(I18N.ja)`** 에서 만든다(index.html ~20154). → **ja 블록에 키를 추가하면 그 키가 어드민 언어시트에 자동으로 나타난다.** 별도 등록 작업 불필요.
- 운영자가 언어시트에서 수정하면 Supabase `i18n_translations`(key, lang, value) 테이블에 override로 저장되고, Realtime으로 전 사용자에 즉시 반영(정적 `I18N`은 안전망 fallback).
- 따라서 새 UI 만들 때 **할 일은 §2-3대로 키를 4블록(특히 ja)에 넣는 것뿐.** 그러면 ① 앱에서 4개국어로 보이고 ② 어드민 언어시트에서 편집 가능해진다.
- ⚠️ ja 블록에 키가 없으면 언어시트 목록에 안 뜬다 → **ja에 반드시 추가**(ko/en/zh도 같이).

---

## 5. 커밋 전 체크리스트 (필수)

1. [ ] 사용자 대면 텍스트에 하드코딩 리터럴이 남아있지 않은가(정적=`data-i18n*`, 동적=`t()`).
2. [ ] 키를 **ja/ko/en/zh 4블록 모두**에 추가했는가:
   ```bash
   grep -oE "'그_키':" public/index.html | wc -l   # → 4 여야 함
   ```
3. [ ] JS 문법검사 통과:
   ```bash
   node -e "const fs=require('fs');const h=fs.readFileSync('public/index.html','utf8');const m=h.match(/<script>([\s\S]*?)<\/script>/g)||[];let bad=0;m.forEach((s,i)=>{const b=s.replace(/^<script>/,'').replace(/<\/script>$/,'');try{new Function(b)}catch(e){bad++;console.log('SCRIPT#'+i,e.message.split('\n')[0])}});console.log(bad?'ERR '+bad:'OK '+m.length)"
   ```
4. [ ] 빌드번호 2곳 올림: `window.__APP_BUILD__`(index.html), `CACHE_NAME='...-bNNN'`(sw.js).
5. [ ] (어드민/SEO 예외인 경우) 의도적으로 제외한 것이 맞는지 확인.

---

## 6. 흔한 함정

- **한 곳 누락 → 폴백**: ko에 키 빠지면 한국어에서 일본어가 나온다. 항상 4블록.
- **자식 요소 날림**: 아이콘/뱃지 span 있는 컨테이너에 `data-i18n` 직접 달면 자식 삭제됨 → 텍스트만 span으로.
- **작은따옴표/아포스트로피**: 키 값은 작은따옴표 문자열. 영어 `you'll` 같은 `'`는 `you will`로 바꾸거나 이스케이프(문법 깨짐 주의).
- **언어 변경 중 동적값 덮어쓰기**: JS가 매번 세팅하는 동적 텍스트(예: 선택된 카테고리 라벨)에는 `data-i18n`을 달지 말고 JS에서 `t()`로 처리(언어 변경 시 재렌더 함수가 다시 그림).
- **숫자/통화**: `¥`는 그대로, 단위어(件/건/개 등)는 키로.

---

## 7. 참고
- 전체 i18n 적용 이력·잔여 목록: **`I18N_TODO.md`**.
- i18n 메커니즘 코드: `applyLang()`·`t()`(~14547), `var I18N`(~13448), CMS(~14657), 어드민 언어시트 목록(~20124/20154).
- 잔여(저빈도): 코인 내역 라벨(`ctAddCoin` 일본어 라벨 → `coinlog.*` 일괄), `renderPriceComparison`, 업로드 확인 모달 엣지.
