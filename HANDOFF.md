# RetWork (チリつも) — HANDOFF (build 515 시점)

> 다른 컴퓨터에서 이어서 작업할 때 이 파일부터 읽으면 현황 파악 완료.
> 최신 빌드: **build 515** · 도메인: **retwork.jp** · 일본 시장 타겟 영수증 OCR + 가성비 가게 정보 공유 PWA.
> 블로그(SEO/AdSense): **blog.retwork.jp** (별도 레포 `SMW-Code/retwork-blog`, 로컬 경로 `C:\Users\minus\Desktop\retwork-blog`)
> 마지막 작업: **2026-06-16** (b500~515 — 1日平均 분모 수정, i18n 누락 다수, 스캔시트 리디자인, 치리공개 중복방지, 주차요금 ¥/시간 비교)
> ⚠️ **SQL 실행 필요(신규/이어받는 PC가 아니라 DB 기준):**
> - `product_prices.sql`(b498), `product_prices_volume.sql`(b503) — **실행 완료**(사용자 확인).
> - 🔴 `items_parking_mins.sql`(b515) — `alter table public.items add column if not exists mins integer;` **실행 필요**. 미실행 시 저장은 정상이나(클라가 mins 자동 제외 후 재시도) 주차시간이 DB에 영구 보존 안 됨 → 새로고침 후 주차 ¥/시간 비교가 사라짐.

> ⚠️ **작업 규칙(중요):** 개발 단계 동안 변경은 **`main`(production)에 직접 커밋·push**(dev 건드리지 말 것, gh CLI 없음 → PR 클릭생성 불가). 변경 시 **빌드번호 2곳**(`index.html`의 `window.__APP_BUILD__`, `sw.js`의 `CACHE_NAME='...-bNNN'`) 같이 올리기. 커밋 전 아래 문법검사 필수.
> ```bash
> node -e "const fs=require('fs');const h=fs.readFileSync('public/index.html','utf8');const m=h.match(/<script>([\s\S]*?)<\/script>/g)||[];let bad=0;m.forEach((s,i)=>{const b=s.replace(/^<script>/,'').replace(/<\/script>$/,'');try{new Function(b)}catch(e){bad++;console.log('SCRIPT#'+i,e.message.split('\n')[0])}});console.log(bad?'ERR '+bad:'OK '+m.length)"
> ```

---

## 0-J. 2026-06-16 — 홈 지표 수정 · i18n 누락 보강 · 스캔 UI · 치리 중복방지 · 주차 단가비교 (build 500~515)

순서대로 진행한 작업 묶음. 모두 `main`에 push 완료.

### A. 1日平均(일평균) 분모 수정 (b505~506)
달력/리포트의 「1日平均」이 `월총액 ÷ 그달전체일수`라 진행중인 달에서 남은 날(¥0)까지 포함돼 과소 표시됨(예 6/16에 77,485엔인데 ¥2,583). → `_avgDivDays(y,m)` 헬퍼: **진행중인 달=경과일(오늘 날짜), 지난 달=전체일수**. 적용 3곳: `renderReportSummary`(~9253), 월간리포트 `mr`(~10063 `renderMonthReport`), 달력(~9689). (홈 카드 순서도 b504에서 월간리포트→광고→절약찬스로 변경됨)

### B. i18n 잔여 한국어 노출 보강 (b507~512) — 일본어 모드인데 한글 노출되던 곳들
- **b507** 토스트/확인창 19종: 댓글제한/별점실패/비공개메모삭제/추천코드복사/다크모드전환/Apple로그인/금지어·차단/신고 등 → ja/ko/en/zh. (어드민 `_adm*` 토스트는 운영자전용이라 한국어 유지)
- **b508** 이력-리포트 하단 미구독 「더보기」 카드(제목/설명/광고버튼) → `rep.more_*` data-i18n
- **b509** ★`_getWatchAdOptsByContext()` 컨텍스트 매트릭스 **전체가 하드코딩 한국어**였음(save/chiri/private/menu_photo/monthreport/report_unlock/comment_quota/default). → `wad.*`/`repunlock.*` 키. 모든 광고시청 풀스크린 페이지 영향
- **b510** 월별리포트 공유텍스트(`mrShare`) `RetWork 리포트` → `mr.share_text/title`
- **b512** ★ `openMonthReport()`가 한국어 `opts`로 base를 override해서 b509 후에도 월별리포트 광고페이지가 한국어였음 → `t('wad.monthreport.*')`. + `showAdModal` 외식저장 보조버튼 「+치리공개」 → `wad.secondary_chiri`
  - ⚠️ 교훈: `openWatchAdPage`는 카드 제목/설명=`opts||base`, 메인버튼라벨=`base`. opts 넘기는 호출부가 한국어면 카드만 한국어로 보임.

### C. 수동기입 모달 i18n + 스캔시트 리디자인 (b511, b513)
- **b511** 영수증모드 + 수동기입 모달: 카테고리 칩 하드코딩 한글 라벨 → `CAT_LABEL[k]`(Proxy 자동번역) 사용. `cat.fuel`/`cat.park` 키 신설 + `_CAT_LABEL_KEYS` 매핑 보정(주유→기타·주차→교통으로 뭉개지던 것 분리). 저장버튼 `manual.save`(기존키), 품목 placeholder `manual.ph_*`
- **b513** 스캔 선택 시트(`ov-scan`+`ov-scan-camera`) 한일혼용 텍스트 i18n(`scan.camera.sub`/`scan.manual.*`/`scan.cam.*`) + **디자인 현대화**: 이모지→SVG 라인아이콘+컬러틴트 타일(카메라 그린/갤러리 인디고/수동 골드), surface카드+그림자+라운드18px, `.scan-opt` CSS 갱신, NEW 배지 pill

### D. 치리츠모 공개 중복방지 (b514)
치리맵 가게 리스트 펼침 → 「チリつもに公開する」. `store_menu_cards`(전체공개 RLS) 캐시(`window._chiriPubByStore`, `_normChiri`정규화)로 이미 공개된 가게/메뉴 식별:
- **공개 모달**(`openChiriPublish` async화): 이미 공개된 메뉴 칩=`公開済み` 비활성(선택불가), 기본선택=미공개만, 전부 공개시 제출차단(`submitChiriPublish` 가드)+안내배너(`cp-all-published-notice`)
- **맵 카드**: 공개대상 메뉴(상위5/가게명) 전부 등록되면 골드버튼→`✓ チリつもに公開済み` 비활성
- 공개 성공 후 `_loadChiriPublishedCache(true)`→`renderMapPins()` 즉시 반영. 키: `chiri.already_pub/all_published/map_published/map_publish_btn` 등

### E. 주차요금 시간당 단가(¥/시간) 비교 (b515) — 🔴 SQL 필요
주차요금은 주차시간 따라 총액이 달라 단순 비교 왜곡(¥300 vs ¥2,800 → 잘못된 89% 절약). → 시간기반 품목은 **¥/시간**으로 비교.
- `_isParkingItem(name,cat)`(cat==='park' or `_PARKING_RE`), `_parseParkingMins(rawText)`(`駐車時間 H:MM`/`N分` 또는 入庫·精算/出庫 시각차이, 자정넘김 보정), `_fmtMins`
- `_doSaveOcrResult`: OCR 원문(`window._rawOcrText`)에서 주차시간 파싱→주차 품목에 `.mins` 보존. items insert에 `mins` 포함하되 **컬럼 미존재 시 자동 제외 후 재시도**(저장 무손실). 로드(`items(*)` 매핑 ~16658)에 `mins` 추가
- `renderPriceComparison`: 주차 품목은 `총액÷(mins/60)`=¥/시간 비교, **mins 없는 관측은 비교 제외**(오해방지), `時間単価` 태그+안내문. 가격비교 한국어 노출도 `pc.*` 키로 i18n화
- 🔴 **`items_parking_mins.sql` 실행 필요**(헤더 참조). 파서 단위테스트 통과
- **미완(후속 후보):** 영수증 편집/수동입력 모달에 「주차시간」 입력칸 추가(과거/누락 데이터 직접 채우기). 사용자에게 진행여부 물어본 상태.

### 커밋 (모두 push)
`b505/b506`(1日平均) → `b507`~`b513`(i18n/스캔) → `b514`(치리 중복방지) → `b515`(주차 ¥/시간). HEAD=`1902841`(b515).

---

## 0-I. 2026-06-16 — 「節約チャンス」 더미 → 위치기반 커뮤니티 실구현 (build 497~499)

영수증 홈 「節約チャンス発見」(`ov-saving` + 홈 `home-saving-banner`)이 **하드코딩 더미**(牛乳/食パン·¥1,320 고정)였던 것을 **실데이터**로 단계적 교체. ✅ 0-H의 미결정 TODO 해결.

**b497 — 1차(내 영수증 이력):** `_computeSavings()` 가 로컬 `DB`(내 영수증)에서 "같은 상품(정규화명)을 2곳 이상 마트에서 산 단가 차이"를 계산. 홈 배너는 절약액 있을 때만 표시(없으면 숨김 — 가짜 금액 제거), 모달은 상품별 마트비교+합계. 빈 상태='수집중'. **한계: 내가 가본 마트끼리만 비교**(타 유저 미반영).

**b498 — Phase 1(커뮤니티 가격 풀 기반):** ★`product_prices.sql` (공개 테이블: `product_id·store_name·price·lat/lng·user_id`, 유저당(상품,가게) 1행 upsert / RLS=전체읽기·본인쓰기). 실행완료. 영수증 저장(`_doSaveOcrResult` 의 `searchAndPinStore` 콜백)에서 `_contributeProductPrices(finalItems, store, lat, lng, r.cat)` 호출 → **식료품(cat==='food')** 품목의 정규화 product_id(`_matchOrCreateProduct`) + 가게 + 단가 + 좌표를 upsert. → 데이터 축적 시작.

**b499 — Phase 2(위치기반 비교, 현행):** `_computeSavings()` **async 전환**:
1. 내 구매(로컬 DB, 최근3개월) → 상품별 내 평균단가·월구매수량
2. 잠재절약 상위 20개만 `_matchOrCreateProduct`로 product_id 정규화
3. 공개 `product_prices` 조회(`.in('product_id', pids)`)
4. **내 위치 `_ctUserPos` 반경 5km**(`_calcDistanceM` Haversine) 내 같은 상품 최저가(**타 유저 가게 포함**) 탐색
5. 절약 = (내 평균단가 − 근처 최저가) × 월구매수량. 커뮤니티 데이터 없으면 **내-이력(2+가게) 폴백**. 60초 캐시
- 배너/모달 async(로딩 표시). 모달 = "내 구매 ¥X vs 근처 최저가게 ¥Y(-¥차액)".
- 핵심 함수: `_computeSavings`(async)/`_updateSavingBanner`(async)/`openSavingAnalysis`/`renderSavingAnalysis`(async)/`_contributeProductPrices`. i18n `home.saving_sub`·`saving.based_on/per_month/buy_basis/you/empty_*`.

**커밋:** `bad2647`(b497) → `b06a9dd`(b498 +product_prices.sql) → `05f15f9`(b499). 모두 push.
**⚠️ 현실 의존:** product_prices 는 b498 이후 식료품 영수증이 쌓여야 의미. 초기엔 대부분 폴백/'수집중'. **다음 후보:** 수동입력 식료품도 기여(현재 OCR 저장 경로만), 반경 km 튜닝, 같은 상품 다른 브랜드 과병합 방지(현재 정규화명 기준), product_prices 오래된 가격 만료/가중평균.

---

## 0-H. 2026-06-15 — 치리맵 영수증등록 · UI 정리 · SNS · 블로그 (build 489~496)

### A. 치리맵 「영수증으로 등록」 + 수동핀 사진 (b489~490)
수동핀 모달(`ov-manual-pin`) 확장:
- 상단 **「📸 レシートで登録（自動入力）」** 버튼(`ctReceiptRegisterStart`) → 카메라/갤러리(`ct-receipt-input`) → 기존 OCR 파이프라인(`handleImageFile`→preprocess→Vision→GPT→`showOcrResult`) → `window._scanForChiriMap` 플래그로 **기존 치리공개 모달(`ov-chiri-publish`)로 자동 라우팅**(`saveAndPublishChiri`). 사진/메뉴카드/광고는 치리공개 플로우 재사용
- **위치 자동 추정(b490)**: `window._cpForcedPos`(지도중앙)=초기 fallback일 뿐, `submitChiriPublish`가 **OCR 가게명+주소로 `searchAndPinStore` 지오코딩** → 실제 가게 위치에 핀(b489의 "지도중앙 고정+지오코딩 skip"은 폐기). `openChiriPublish`에서 `_cpForcedPos`→`_cpPos` 소비
- **수동입력 경로 사진**(b489): 가게 대표사진(`mp-store-photo`/`mpPickStorePhoto`) + 메뉴별 사진(`mpPickItemPhoto`, `_mpItems[i].photoFile`). submit 시 `_mpPersistPhotosAndCards` → `store_community_photos` + `store_menu_cards`(메뉴카드 생성/갱신, 사진 첨부 — chiri-publish 로직 미러). ⚠️ 이제 수동핀도 메뉴카드를 생성함(가격핀만 만들던 기존 동작 변경, 의도적). `_cpUploadPhoto` 재사용(store-photos 버킷)

### B. UI 정리 (b491~493)
- 치리모드 상단 헤더 4종 **이모지 전체 제거**: 📍チリつも(셰브론 유지)/💬チリトーク/🎴チリカード/🎁チリワード → 텍스트만. (チリカード/チリワード는 `ct.mycard.title`/`ct.reward.title` i18n 값에서도 제거)
- 수동핀 모달 카메라 아이콘 통일(b493): 📸·📷 이모지 → 가게사진 슬롯과 동일한 **심플 SVG 카메라**(stroke=currentColor)

### C. 설정창 (b494~496)
- **グルメブログ** 링크 추가(b494): 節約ブログ(`./blog/`=retwork.jp 정적 절약블로그) 아래에 `blog.retwork.jp`(신규 그루메 블로그) 링크. i18n `settings.gourmet_blog`
- **SNS 바로가기**(b495~496): 로그아웃 아래 X·Instagram·Threads 원형 아이콘(브랜드 SVG). `RETWORK_SNS`(코드 한 곳에서 URL 관리)+`ctOpenSns(key)`, 비면 `toast.sns_soon`. **연결된 계정**: X=`https://x.com/RetWork2026` / IG=`https://www.instagram.com/retwork.jp/` / Threads=`https://www.threads.net/@retwork.jp`

### D. 블로그 (retwork-blog) — 9편째
- **`gyoza-fukubukuro-toyosu.md`** — 餃子の福包 豊洲店(ららぽーと豊洲3F) 餃子 리뷰 ★4.0. 사진 11장(외관/메뉴스탠드/내부/태블릿/조미료/타레/焼き·揚げ·水 餃子/鶏玉ご飯/레시트). 태블릿주문·薬味 5종·にんにく抜き 선택. 커밋 `157fda3`

### 커밋 (모두 push 완료)
- receiptiq: `f2c7e67`(b489) → `198d05f`(b490) → `629d370`(b491) → `186bcdc`(b492) → `1ffacfa`(b493) → `834a16f`(b494) → `d450470`(b495) → `c3b0087`(b496)
- retwork-blog: `157fda3`(餃子の福包 글)

### ✅ (해결됨 — b497~499, 위 0-I 참조) 영수증 홈 「節約チャンス発見」 더미 → 실구현 완료
> 아래는 당시 더미 진단 기록(히스토리). 실제 구현은 **0-I** 참조.

#### (히스토리) 당시 더미 진단
- `ov-saving` 모달([index.html](public/index.html) ~2713)은 **완전 하드코딩 목업**: 牛乳/食パン, イオン vs 業務スーパー, ¥1,320/月·年¥15,840 전부 고정. DB(`items`/`price_pins`/`products_master`) 안 읽음. 누가 뭘 등록하든 같은 숫자.
- 홈 배너(`index.html` ~1246, `onclick="openOv('ov-saving')"`) + i18n `home.saving_cta`/`home.saving_cta_sub`도 고정 문구.
- **방향 미정(사용자 결정 대기)**: A) 실구현(내 영수증 품목→`products_master` 정규화 매칭→타 마트 `price_pins` 최저가 비교→실제 절약액. 데이터 부족 시 "수집중" 표시) / B) 일단 배너 숨김(가짜 금액 노출 방지) / C) "サンプル" 데모 배지. **추천: B→A.**

**문제:** GSC `https://retwork.jp/index.html` → 「중복 페이지, Google이 사용자와 다른 표준 선택」. 사용자 선언 canonical=`/index.html`(b473)을 **Google이 무시하고 루트 `/` 를 표준으로 재선택**. 그런데 `/` 는 `app/page.tsx` 의 307 리다이렉트(비콘텐츠)라 색인 불가 → 둘 다 색인 실패.

**해결(=Google 선호 `/` 에 맞춤):**
- `next.config.ts`: **`async rewrites(){ return { beforeFiles:[{source:'/',destination:'/index.html'}] }; }`** → 루트 `/` 가 **307 아닌 200**으로 정적 `public/index.html` 콘텐츠를 서빙(URL 그대로, `?ref=` 보존). `beforeFiles` 라 `app/page.tsx` 보다 먼저 적용(페이지 오버라이드). `app/page.tsx`(ref보존 리다이렉트)는 폴백으로 **존치**.
- `next.config` headers 에 `source:"/"` no-store 추가(스테일 방지).
- index.html `<link rel=canonical>` + JSON-LD `url` + sitemap 홈 `loc` 를 `/index.html` → **`/`** 환원.

**검증:** `next build` 통과(16.2.6). 로컬 `next start`: `/`=200(본문 canonical=/ · __APP_BUILD__ 포함), `/?ref=TEST`=200, `/index.html`=200. **GSC 실시간 테스트: "URL을 Google에 등록할 수 있음" + 사용자 선언 표준=`https://retwork.jp/` 확인 → 색인 생성 요청 완료(2026-06-15).** Google 선택 표준은 재크롤(수일) 후 `/` 로 일치 예정.
**커밋:** `18715e8` (push). build 488 / sw b488.
**⚠️ 함정:** `/` → `/index.html` 은 **rewrite(200)** 여야 함(redirect 금지 — 색인 안 됨). canonical/sitemap/JSON-LD 전부 `/` 로 통일. (b470 redirect·b473 self-/index.html 은 폐기된 접근). 남은 권장: Vercel 도메인에서 `www.retwork.jp`→`retwork.jp` 리다이렉트 확인(GSC 참조페이지에 www 있었음).

---

## 0-F. 2026-06-15 세션 — 치리카드 개편 (build 484~486)

**요청:** 치리카드 탭에 페이지뷰 + 광고카드 + 필터(가격/카테고리/지역 都道府県→시정촌). 3단계로 진화 — **최종(b486) 상태가 현행:**

**구성(최종):**
- **카드종류 2종**: 「マイカード(내 카드, created_by=본인, 기본)」 / 「みんなのカード(전체 — 모든 유저 가성비 발견)」. 필터 바텀시트 안에서 선택(서브탭 아님). 진입 기본=마이카드
- **페이지뷰**: 페이지당 메뉴카드 **10 + 광고카드 2** (`CC_PER_PAGE=10`, `CC_AD_AFTER=[4,9]` → 4·9번째 카드 뒤). 광고카드 `_ccAdCardHtml`=메뉴카드 행 동일 크기(96px dashed 📢 `rw.ad`, AdSense 승인 후 교체). 하단 prev/next 페이저(`md.prev`/`md.next`)
- **필터 = 바텀시트**(b485, 치즈맵 필터와 동일 패턴): 상단 펀넬 **필터 버튼**(적용 수 배지) → `cc-filter-sheet`(position:fixed z1201 + `cc-filter-dim` z1200). 시트 내용: 카드종류 세그먼트(`.cc-src-btn`) · 가격 슬라이더(¥300~3000, **상한 방식**, 3000=무제한) · 카테고리 칩(맵의 `.ct-cat-chip` + `ct.cat.*` **canonical 키** 재사용) · 지역 셀렉트(都道府県→시정촌) · 初期化/適用. 카테고리 매칭 = `card.category.toLowerCase()===chip` 
- **상단바 한 줄(b486)**: 마이카드면 `[컴팩트 요약3(카드/확인/좋아요) + 필터버튼]`, 전체면 `[소스라벨 + 필터버튼]`. 요약은 별도 행 아님 → `_ccRenderTopbar` 가 통합(컨테이너 `#cc-topbar` flex stretch). 요약 셀 padding 9px·폰트 17/9 로 컴팩트
- **지역 추출**: store_menu_cards엔 지역 없음 → 소스별 로드 시 `stores.address`(OCR 자유텍스트) 200개 청크 조회 → `_ccParseRegion`(47都道府県 prefix + 첫 市/区/町/村) 파싱해 `_pref/_city` 부착. 미상=「기타(`__other`)」. **별도 DB 작업 없음**

**핵심 함수**(index.html `renderMyCards` 영역 ~5847): 데이터=`_ccEnsureData(src)`(소스별 fetch+지역부착, `_ccDataCache={mine,all}` 캐시) · `_ccActiveRows` · `_ccParseRegion`/`_JP_PREFS`. 진입=`renderMyCards`(진입마다 활성소스 캐시무효화 후 재로드). 상단바=`_ccRenderTopbar`/`_ccActiveFilterCount`. 시트=`_ccOpenFilter`/`_ccCloseFilter`/`_ccPickSource`/`_ccSheetPrice`/`_ccUpdatePriceLabel`/`_ccSheetCat`/`_ccFillRegionSelects`/`_ccFillCitySelect`/`_ccSheetPref`/`_ccSheetCity`/`_ccResetCardFilter`/`_ccApplyCardFilter`. 그리드=`_ccFilteredRows`/`_ccRenderGrid`(건수+타일+광고+페이저)/`_ccGoPage`/`_ccAdCardHtml`. 상태=`_ccTab`(적용소스)/`_ccPendSource`(시트선택)/`_ccPriceMax`/`_ccCat`/`_ccPref`/`_ccCity`/`_ccPage`. `_myCardItemHtml`/`_myCardDateStr`/`myCardOpen` 재사용. i18n `cc.*`(tab_mine/tab_all/source/region/region_all/region_other/city_all/no_result/count/all_empty_sub 등) 4로케일.
**🔴 지역 필터 수정(b487) — 중요:** 처음엔 지역을 `stores.address` 에서 파싱했으나 **stores 엔 주소가 저장 안 됨**(`_persistPinToSupabase`·admin 모두 address 미기록, 주소는 receipts에만 희박) → 전부 「기타」로 빠져 도도부현이 안 떴음. **수정 = 좌표 역지오코딩**: 거의 모든 가게에 있는 `stores.lat/lng` 를 Google Maps Geocoder(이미 로드)로 역지오코딩 → 都道府県/시정촌. `_ccRegionCache`(localStorage `cc_region_cache` 영구 캐시) + 백그라운드(`_ccGeocodeMissing`, 미캐시만 스로틀 110ms·세션당 150건 상한, 맵API 로딩 전이면 1.5s×4회 재시도). 지오코딩 완료 시 시트 도도부현 옵션·지역필터 결과 자동 갱신. 東京 23구는 sublocality_level_1(◯◯区) 보정. **두 탭 모두 DB 작업 없이 동작.** ⚠️ 첫 진입 직후 필터 열면 아직 지오코딩 중이라 도도부현 일부만; 몇 초 뒤/다음 진입부턴 완전. 관련 함수: `_ccGeocodeLatLng`/`_ccGeocodeMissing`/`_ccRegionCache`/`_ccSaveRegionCache`. (`_ccParseRegion` 제거됨)

**커밋:** `1c0ed19`(b484 초기·서브탭형) → `15b8b0f`(b485 바텀시트화) → `79babc6`(b486 요약+필터 한 줄) → `68b03f6`(b487 지역 좌표 역지오코딩). 모두 push. build 487 / sw b487.
**⚠️ 데이터 의존:** 지역=`stores.lat/lng` 역지오코딩(주소 불필요). 전체 탭은 `limit(1000)` 클라 필터링(추후 서버사이드/무한스크롤 검토). 카테고리 칩은 맵 canonical 키 기준이라 store_menu_cards.category 가 다른 값이면 「すべて」서만 보임. 지오코딩은 Google 과금 대상 — 캐시로 1회/가게 제한하지만 'all' 탭 대량이면 비용 주의(상한 150).

---

## 0-E. 2026-06-14 세션 — 안드로이드 뒤로가기 · 치즈맵 가격핀 (build 474~483)

### A. 안드로이드 PWA 시스템 뒤로가기 전면 개편 (build 474~480) — 완료
**문제:** 안드로이드 PWA에서 시스템 뒤로가기 시 모달이 역순으로 닫히지 않고 앱이 바로 종료. 베이스 탭 종료 전 토스트도 불안정.
**근본 원인:** 안드로이드 PWA는 `popstate` 핸들러 **안에서** 호출한 `history.pushState`를 무시 → 가드 재설치 실패.
**해결 모델:**
- **모달 열 때** 미리 `history.pushState({riqNav:1},'')` 엔트리를 쌓음(사용자 액션에서, popstate 밖).
- **UI로 닫을 때**(`closeOv` 등)는 `window._riqInPop` 가드 하에 `history.back()`으로 동기화, `window._riqExpectPop` 카운터로 중복 방지.
- 뒤로가기 핸들러 `_closeTopModal()`이 ① openOv 스택(.open) ② DOM `[id^="ov-"].open` ③ **display 기반 풀스크린 오버레이**를 z-index 내림차순으로 닫음.
- **베이스 가드 재설치(b478):** 가드가 한 번 소비되면(첫 종료 토스트 후) 다음 화면 탭(pointerdown) 시 `_ensureBaseGuard`로 재push → 종료 토스트 **항상** 표시.

**display 기반 풀스크린 전수 동기화(b479~480):** `.open` 클래스 없이 `style.display='flex'`로 여는 풀스크린들도 모두 열 때 pushState / 닫을 때 history.back 동기화 + `_closeTopModal` 등록:
`ov-ct-post-detail`(게시글상세 z370)·`ov-ct-store-full`(치리스토어 z360)·`ct-write-ov`(글쓰기 z350)·`ov-img-viewer`(z9999)·`ov-avatar-crop`(z9999)·`ov-month-report`(월간리포트 z380)·`ov-admin-pc`(어드민 z9500).
**의도적 제외:** `ov-reward-ad`(보상형 광고) — 뒤로가기로 닫으면 광고 스킵=매출손실 → **보류(미결정, 아래 ▶다음 후보).**

### B. 치즈맵 가격핀 — 어드민엔 보이는데 지도엔 안 뜸 (build 481~483) — 완료
**원인(실데이터 확정):** 어드민 가게핀 목록과 치즈맵 마커는 **같은 `price_pins` 테이블**. 지도 쪽에만 걸리는 필터로 누락. 사례 `cafe&meal MUJI東京有明` 핀 `選べる4品デリセット`=**¥1,550**인데 가격필터 기본상한 **¥1,500**을 50엔 초과 → 조용히 숨겨짐.
**지도 필터 4종(`ctLoadPricePins`/`ctRenderPricePins`):** ①가격상한 `price>_ctPriceMax`(기본1500/슬라이더max3000) ②좌표 null ③`.limit(300)`(지역필터 없음, 어드민은 1000) ④카테고리.
**최종 해결(b483) — 숨기지 말고 비활성(흐림) 마커로:**
- `ctRenderPricePins`: `_ctPins`를 **가게 단위 그룹화**(`_allGroups`) → 대표가격(`featured_price`>최저가)으로 `_activeGroups`(상한이하/pending) vs `_dimGroups`(초과) 분리(`g._dim`).
- 공통 헬퍼 `_ctAddStoreMarker(group,isDim)`: 활성 opacity 1 / 비활성 0.38.
- **확대(개별, zoom≥`CT_CLUSTER_ZOOM`=17):** 활성=선명 + 비활성=흐림 개별 마커.
- **축소(클러스터):** 활성+비활성 한 셀로 묶어 숫자 원형. **셀에 활성 하나라도 있으면 선명 클러스터, 전부 비활성이면 흐림 클러스터(opacity 0.42)**. 카운트는 둘 다 포함.
- 슬라이더 올려 적용 시 비활성→활성 전환(가성비 컨셉 유지). `ctApplyFilter`/`ctResetFilter`가 재렌더.
- (b481의 `+N` 숨김배지는 "뭔지 모르겠다" 피드백으로 b482에서 제거)

### 커밋 (2026-06-14, 모두 main push 완료)
`51e3587`(b478 베이스가드복구) → `d7f8f48`(b479 게시글상세) → `1bbdef6`(b480 display전수) → `61ad649`(b481 숨김배지) → `024200b`(b482 비활성마커) → `aee40b1`(b483 비활성클러스터)
*(b474~477은 직전 세션에서 뒤로가기 1차 시도들 — pushState-in-popstate 문제 진단 과정)*

### ▶ 다음 후보 / 미결정
- **`ov-reward-ad`(보상형 광고) 뒤로가기 처리 미정.** 광고 중 뒤로가기 시 앱 종료됨. (1)뒤로가기 무시(광고·앱 유지, 스킵방지) (2)닫기 — 사용자 결정 필요.
- 안드로이드 실기기에서 b483 뒤로가기/클러스터 최종 확인(데스크톱 프리뷰로는 안드로이드 popstate 재현 불가).
- 치즈맵 `.limit(300)`+지역필터 없음 — 핀 300개 초과로 늘면 오래된 핀 누락 가능(현재 전체 26개).

### 데이터 직접 확인법 (Supabase REST, 공개키 = `index.html` `supabase.createClient` 2번째 인자)
```bash
KEY="<publishable key>"; URL="https://fkvfbxfgidrvymoftkdd.supabase.co/rest/v1"
curl -s "$URL/stores?name=ilike.%25키워드%25&select=id,name,lat,lng,featured_price" -H "apikey: $KEY" -H "Authorization: Bearer $KEY"
curl -s "$URL/price_pins?store_id=eq.<id>&select=item_name,price" -H "apikey: $KEY" -H "Authorization: Bearer $KEY"
```

### 로컬 전용/미커밋 (production에 올리지 말 것)
- `public/scan-proto.html`·`public/receipt-parser.js` — dewarp(원근보정) 프로토타입, **셸브**. `public/` 아래라 커밋하면 retwork.jp에 공개됨 → **커밋 금지**.
- `test1.jpg`~`test7.jpg` — 파서 검증용 로컬 테스트 사진. 커밋 불필요.

---

## 0-D. 2026-06-12 세션(이어서) 변경 요약 — 블로그 · 잔여 i18n · SEO

### 메인 앱 (receiptiq) — build 471 ~ 473

| build | 내용 |
|---|---|
| **471** | **'대표' 뱃지 다국어화** — 가게 상세 사진(단일/슬라이드)·메뉴 상세 사진·메뉴카드의 하드코딩 `⭐ 대표` 4곳 → `t('badge.featured')`. 언어시트 4로케일 추가(ja=代表/ko=대표/en=Featured/zh=招牌). ★ 이모지는 마크업 유지. **어드민** 가게목록·핀행·메뉴편집의 '대표' 표기는 한국어 유지(운영자용) |
| **472** | **사용자 대면 잔여 한국어 17곳 일괄 i18n** (Explore 에이전트로 전체 스캔) — ① 메뉴 상세 평가폼: 내 평가 수정하기/평가 작성/수정하기/평가 등록/취소/"✏️ 내 평가 수정" 제목 ② 가게리뷰 동기화 토스트(실패/RLS/생성실패)·수정실패 alert ③ 차단어 토스트 2곳→기존 `toast.banned_word` 재사용 ④ 출석 추가광고 보너스: 베타우회/남은횟수/슬롯/대기/완료 + 「광고 보고 チリ 받기」(정적 `data-i18n`+동적) ⑤ 스캔 멀티촬영 안내(촬영순서/장수) ⑥ 공유 이미지저장 토스트 ⑦ 리워드 교환 placeholder. 신규 i18n 키 22개(4로케일). `t(key,params)` 는 `{var}` 다중 보간 지원 확인 |
| **473** | **SEO canonical 색인 충돌 수정** ⭐ — GSC 「적절한 표준 태그가 포함된 대체 페이지」로 `/index.html` 색인 실패. **원인 = canonical 순환**: index.html 의 canonical 이 `/` 를 가리키는데 `/` 는 `/index.html` 로 307 리다이렉트(b470)되는 비콘텐츠 URL → Google 이 `/index.html` 을 `/` 의 대체본으로 보고 색인 제외, `/` 는 리다이렉트라 색인 불가 → **둘 다 색인 실패**. **수정**: ① index.html `<link rel=canonical>` `/` → `/index.html`(self-canonical) ② JSON-LD `url` 동일 ③ sitemap 홈 `loc` `/` → `/index.html`, lastmod 2026-06-12. ⚠️ **라우팅/ref 리다이렉트(app/page.tsx)는 그대로 유지** — 메타데이터만 수정. 홈은 `retwork.jp/index.html` 로 색인됨(깔끔한 `/` 색인 원하면 redirect→rewrite 200 으로 바꿔야 하며 next.config 수정 + 루트 no-store 헤더 필요, Next16 rewrites API 검증 후). 배포 후 GSC URL검사→색인요청→유효성 재검사 필요 |

### 블로그 (retwork-blog) — 8편째 글 + SEO
- **`ginza-kagari-otemachi.md`** — 銀座 篝 大手町店 鶏白湯Soba 리뷰 ★4.0 (미슐랭 출신/블룸버그 보도, 키오스크 결제 함정·2열 줄서기·〆ご飯 등). 사진 6장(`public/images/ginza-kagari-otemachi/`: main/sign/exterior/topping/condiments/receipt, 1400px 리사이즈). 커밋 `0860d1a`
- **포스트 SEO 개선** (`b67d96d`, `app/posts/[slug]/page.tsx`): ① `BlogPosting` JSON-LD(headline/image/datePublished/author/publisher) ② 글 하단 「他の記事も読む」 최신 4개 상호 내부링크. → GSC 「발견됨-현재 색인 생성되지 않음」(discovered, not indexed) 완화 목적
- **GSC 「발견됨-색인 안 됨」 진단(2026-06-12)**: 블로그 글 5개가 이 상태. **버그 아님** — 블로그는 SSG(force-static, 본문 서버렌더)·canonical 정확·robots index·sitemap 동적·홈 내부링크 전부 정상. 원인=신규 도메인 낮은 크롤 우선순위. **해결 = 사용자가 GSC URL검사→색인요청(가장 효과적) + retwork.jp→blog 백링크 + 시간.** 코드로 막는 요소 없음

### 커밋 (2026-06-12 이어서)
- receiptiq: `b26b0b8`(b471 badge i18n) → `c2930ad`(b472 잔여 i18n) → `53128b6`(HANDOFF) → `9df79b1`(b473 SEO canonical) — 모두 push 완료
- retwork-blog: `0860d1a`(銀座篝 글) → `b67d96d`(포스트 SEO: JSON-LD + 관련글 링크) — push 완료

### 💡 i18n 작업 메모 (다음에 같은 작업 시)
- 사용자 대면 한국어 찾기: Explore 에이전트에 "user-facing 함수(sd*/md*/ct*/render*/open*, 어드민 adm*/admin* 제외)의 HTML 문자열·토스트 내 한글" 스캔 의뢰가 효율적
- 키 추가 위치: 각 로케일 블록의 `'photo.max5'…'badge.featured'` 줄 뒤에 한 줄로 append (4곳: ja~12502 / ko~12794 / en~13036 / zh~13278 부근)
- 어드민 문구(`_renderStoreRow`/`_renderPinRow`/`openAdminEditMenuCard` 등)는 **한국어 유지**가 규칙
- JS 문법 검증: `node -e` 로 `<script>` 블록 `new Function()` 순회 (JSON-LD `type=application/ld+json` 블록은 스킵)

---

## 0-C. 2026-06-11 세션 변경 요약 — 로고 · 드로우 · 공유

### 메인 앱 (receiptiq) — build 431 ~ 445

| build | 내용 |
|---|---|
| **431** | 치리톡 게시글 카드 댓글 수 — `ct_posts.comments`(stale) 대신 `ctLoadPosts`에서 `ct_comments` 실시간 집계 |
| **432** | 치리츠모 **드로우(추첨) 관리** — 어드민 치리관리에 「드로우 관리」 서브탭(CRUD, `draws` 테이블), 유저측 좌우 슬라이드 카드 캐러셀 + 상세 모달(`ov-draw-detail`, 본문은 추후) ★ `draws_admin.sql` 실행 필요 |
| **433~435** | 드로우 카드 세로 포스터형 캐러셀 재설계 (scroll-snap, 가운데 카드 기준 배치, 더미카드 토글 `_DRAW_SHOW_DUMMIES`) |
| **436** | **로고 전면 교체** — 앱 아이콘/파비콘(`icon*.png`,`favicon.png`)을 RW 그라데이션 둥근사각으로, 실행/인증 화면 로고 추가. sw.js STATIC_CACHE 의 없는 `icon.svg` 제거(install 실패 방지) |
| **437** | 스플래시·로그인 로고를 **투명 핀(open back)** 으로, 흰 틀 제거. manifest `any`=투명핀(`splash-*.png`) / `maskable`=그라데이션(홈 아이콘) |
| **438** | manifest `id="/index.html"` 명시 (WebAPK 식별 안정화 — PWA 설치 멈춤 대응) |
| **439** | **가게 공유 카드** — 가게 상세 공유를 캔버스 카드 이미지(1080×1350: 대표사진+평점+영업시간/전화+대표메뉴+리뷰TOP3)로. `navigator.share({files})` |
| **440** | **메뉴 카드 공유** — 메뉴 상세 모달 공유 버튼(`mdShareMenu`) + 메뉴 전용 카드. 공유 플로우 공통화(`_shareCardFlow`) |
| **441** | **동적 OG 공유 링크** — `app/s/route.ts` 신설. 가게/메뉴별 og:image/title 서빙 → 메신저에 터치 가능한 프리뷰 카드, 클릭 시 retwork.jp 리다이렉트 |
| **442** | 공유 방식 **선택 시트**(`_shareChooser`) — 🔗 링크 공유(OG 프리뷰) / 🖼 이미지 카드 공유 (카카오톡은 이미지 첨부 시 URL 버림 → 분리 필요) |
| **443~445** | 링크 공유 = 풀 카드 캔버스를 `store-photos/share/`에 업로드 → `/s?i=키&r=레퍼럴코드` 단축 링크 공유. 프리뷰엔 풀 카드, 클릭 시 `retwork.jp/?ref=코드`(추천 보상 보존). `t`/`d` 긴 파라미터 제거로 URL 단축 |
| **446** | 드로우 더미카드 완전 삭제 — `renderCtDraws` 가 실제 `draws` 행만 렌더 |
| **447** | **드로우 상세 모달 2종** — 참여 가능(「参加する ✨Nチリ」) / 치리 부족(부족분 안내 + 「広告を見てチリを受け取る」→ 리워드 탭 광고 아코디언). 공통 상단(チリドロー/사진/상품명/추첨형 타원 배지/일정/광고카드). 응모는 서버 RPC `enter_draw`(코인 차감+entry 누적 원자처리) ★ `draw_enter_rpc.sql` 실행 필요 |
| **448** | **치리카드 탭** — 치리모드 하단 4번째 탭 「チリカード」(`ct-screen-mycard`). `created_by`=본인인 `store_menu_cards` 모음(메뉴사진/이름/가게/가격/별점 + 👁확인수). `renderMyCards`/`myCardOpen`. 확인수=`openMenuDetail` 진입 시 `increment_menu_view` RPC +1(본인 제외 누적) ★ `menu_view_count.sql` 실행 필요 |
| **449** | **메뉴카드 중복 등록 방지** — 직접 추가(`_sdDoSubmitNewCard`)에 중복 체크 없어 치리공개+직접추가 시 2개 생성되던 버그. insert 전 같은 가게+정규화 메뉴명 조회→있으면 평점/사진만 병합 ★ 기존 중복은 `menu_card_dedupe.sql`(백업 후 실행) |
| **450** | **어드민 치리카드 관리** — 치리관리 「🎴 치리카드 관리」(`ov-admin-mycards`). 전체 메뉴카드 조회/검색/삭제, 중복(같은 가게+정규화명) 🔴배지+「중복만 보기」. `openAdminMenuCards`/`adminDeleteMenuCard`. 유저 치리카드 탭은 보기 전용(삭제 X) |
| **451** | 치리카드 ① 탭 순서 치즈→**치리카드**→치리토크→치리워드 ② 카드에 등록일시(🕐) ③ **메뉴 좋아요** — 메뉴 상세 ❤️ 토글(`mdToggleLike`, `menu_card_likes`+`toggle_menu_card_like` RPC, store_menu_cards.like_count), 치리카드/요약/어드민에 좋아요수 노출 ★ `menu_card_likes.sql` 실행 필요 |
| **452** | 메뉴 좋아요 버튼을 별점 아래 → 메뉴명 행 공유 버튼 옆(상단)으로 이동 |
| **453~455** | **어드민 가게 목록 중복 표시·삭제** — `_renderStoreRow` 모든 행에 삭제 버튼(`adminDeleteStoreFromList`, 자식 일괄삭제). 중복 판정: 「이름 정규화 일치」 OR 「이름 편집거리 유사도≥0.8 AND 거리<60m」(레벤슈타인+하버사인, union-find) → 신자체/구자체(豊/豐)는 유사+근접으로 잡고 같은 동네 다른 가게 오판 방지 |
| **456** | **오로라 테마** — `THEMES.aurora`(color #6D3BEA 퍼플, grad 시안→블루→퍼플→마젠타→코랄 = RW 로고 그라데이션) 추가 + 기본 테마를 green→aurora. 기존 사용자는 설정→테마에서 직접 선택(localStorage 저장값 유지) |
| **457~458** | **오로라 그라데이션 전체 확장** — `background:var(--green)`/`--gold` 111곳 + 하드코딩 `linear-gradient(…var(--green),var(--green-dark))` 16곳 → `var(--green-grad)`/`var(--gold-grad)`. applyTheme 가 `--green-grad/--gold-grad`=th.grad 설정. 테마 swatch 원/프로필 헤더(sp-head)/프리미엄 카드(prem-banner)도 그라데이션. color/border(단색)는 유지 |
| **459~461** | **유저 대면 i18n** — 하드코딩 한국어/일본어 토스트 44곳 → t()+I18N 4언어. 공유/드로우/추천/출석/프로필/가게수정/가계부/메뉴/위치/영수증날짜 + `theme.name.aurora` 키. 어드민 문구는 한국어 유지(운영자용) |
| **462** | 메뉴 확인수(view_count) 안 오르던 문제 — `increment_menu_view` 의 `created_by IS DISTINCT FROM auth.uid()` 조건이 SECURITY DEFINER 안에서 어긋남 → RPC 무조건 +1(RETURNS INT)로 단순화 + 본인 제외는 클라(`card.created_by===_currentUser.id`)에서. ★ `menu_view_count.sql` 재실행 |
| **463~464** | 영수증 저장 실패/세션끊김 가시화 — receipts insert 실패·`receiptId` 미수신·`user_id` null 시 조용히 누락하던 것 → showToast 경고. (어드민엔 헤더만 저장/품목 누락 = receiptId 미수신) |
| **465** | OCR 파싱 — **음식점 영수증 규칙(RES-1~4)** GPT 프롬프트 추가: 1행 구조+들여쓰기 옵션(味玉 등)도 별도 item / 같은 메뉴 반복 추출 / ★金額 그대로(qty 재곱 금지) / sum==小計 검증. (라면집 영수증 味玉×2 누락·白ごはん ¥400→¥800 오류) |
| **466~470** | **레퍼럴 미작동 근본 해결** ⭐ — 신규 `referred_by` 전부 NULL 이던 원인 = **`app/page.tsx` 의 `redirect("/index.html")` 이 쿼리스트링(?ref=)을 버림** → 추천코드 유실. **b470**: searchParams 받아 쿼리 보존(`/index.html?ref=…`)이 핵심 수정. 보조: b467 OAuth redirectTo 에 ref 부착 / b468 redeem 세션 폴링 재시도 / b469 head 최상단 ref 선캐치 / b466 redeem 실패 토스트. 검증: referral_rewards 행 claimed 까지 정상. ★ `referral_v2.sql` 적용 필요(이미 적용 확인) |

### 공유 기능 핵심 (`sdShareStore` / `mdShareMenu`)
- 공유 버튼 → `_shareChooser` 시트 → 링크/이미지 선택
- **링크**: `_sdBuildShareCanvas`/`_mdBuildShareCanvas`(캔버스) → `_uploadShareCard`(store-photos/share/{key}.jpg, upsert) → `_sShareUrl`(`/s?i=키&r=코드`) → `_shareLinkOnly`
- **이미지**: 캔버스 → `_shareCardFlow`(navigator.share files / 폴백 다운로드)
- `_sdPlaceCur`(Places 캐시)에서 영업시간/전화 공급, `_shareKeyHash`로 결정적 파일명
- `app/s/route.ts`: `i`=share/ 키(영숫자만, 경로조작 차단), `r`=레퍼럴 코드 → `retwork.jp/?ref=` 리다이렉트. 이미지 호스트 화이트리스트(supabase/retwork.jp)

### 로고 파일 (`public/icons/`)
- `icon.png`/`icon-192`/`icon-512`/`favicon.png` = RW 그라데이션 둥근사각 (앱 아이콘/파비콘/홈 maskable)
- `splash-logo.png`(1400, 투명) / `splash-192`/`splash-512`(투명) = 실행 스플래시·로그인 로고 (manifest `any`)
- 원본: `C:\Users\minus\Downloads\open back\open back.png` (투명 RW 핀)

### 블로그 (retwork-blog)
- 로고·파비콘 RW 아이콘 적용 (`app/layout.tsx` 헤더 site-logo + `app/icon.png`)
- 7편째 글: `buta-daigaku-jimbocho.md` (神保町 豚大学 豚丼 리뷰 ★3.0, 사진 7장)

### ⚠️ 이번 세션 SQL — Supabase 실행 필요
- **`draws_admin.sql`** (b432) — `draws` 테이블 sort_order/description 컬럼 + RLS. **실행 완료**(사용자 확인)
- **`draw_enter_rpc.sql`** (b447) — 드로우 응모 RPC `enter_draw`(SECURITY DEFINER, 코인 차감+entry 누적). **실행 완료**(사용자 확인). security_patch 가 draw_entries UPDATE 를 REVOKE 했으므로 이 RPC 없으면 응모 실패
- **`menu_view_count.sql`** (b448) — `store_menu_cards.view_count` 컬럼 + `increment_menu_view` RPC(본인 제외 +1). **실행 완료**(사용자 확인). 치리카드 탭 확인수 집계용
- **`menu_card_likes.sql`** (b451) — `menu_card_likes` 테이블 + `store_menu_cards.like_count` + `toggle_menu_card_like` RPC. **실행 완료**(사용자 확인). 메뉴 좋아요
- **`menu_card_dedupe.sql`** (b449, 선택) — 기존 중복 메뉴카드 병합/삭제. ⚠️ 백업 후 실행. 신규 중복은 b449 로 방지되므로 1회성
- `admin_rls_policies.sql` 의 `stores_admin_delete` — b453 가게 목록 삭제에 필요(미적용 시 삭제 막힘 경고)
- **`cascade_user_delete.sql`** (운영) — auth.users/profiles 참조 FK 를 CASCADE(개인데이터)/SET NULL(created_by·uploaded_by·referred_by) 로 변환 → 대시보드 유저 삭제 자동 정리. ⚠️ FK 변경, 백업 후 1회
- `referral_v2.sql` — 레퍼럴 RPC/테이블(redeem_referral·referral_rewards 등). **적용 확인됨**

### 🔴 레퍼럴/쿼리 관련 핵심 함정 (b470)
- **`app/page.tsx` 의 `/` → `/index.html` 리다이렉트는 반드시 searchParams 를 보존해야 함.** 단순 `redirect("/index.html")` 은 `?ref=` 등 **모든 쿼리스트링을 버려서** 추천 링크·공유 링크가 전부 깨진다. (레퍼럴 referred_by 전부 NULL 사건의 진짜 원인)

### 🔧 남은 정리 작업
- ~~드로우 더미카드 끄기~~ → **b446 에서 완전 삭제 완료** (`_DRAW_SHOW_DUMMIES`/`_DRAW_DUMMIES` 제거, 실제 draws 행만 렌더)
- **드로우 상세 모달 본문**(`ov-draw-detail`) — 사용자가 추후 디자인 제공 예정 (현재 모달 골격만)
- 카카오톡 OG 프리뷰 캐시: 첫 공유 시 이미지 지연 가능 → 재공유 또는 [카카오 OG 캐시 초기화](https://developers.kakao.com/tool/clear/og)

### 커밋 (receiptiq, 2026-06-11)
`6ddd74b`(실행로고) `7e46f48`(아이콘) `9285fce`(b437 투명핀) `82bb8b5`(b438 manifest id) `c2e593a`(b439 가게공유) `5e2301e`(b440 메뉴공유) `29b9c35`(b441 OG링크) `ddacc1a`(b442 선택시트) `c1f668f`(b444 풀카드OG) `0cb736f`(b445 단축)

### 참고
- `package-lock.json` 갱신됨 (`web-push` 의존성 — 새 PC 에서 `npm install` 필수)
- `blog/` 폴더는 node_modules 잔재 → `.gitignore` 에 추가됨 (블로그는 별도 repo)

---

## 0-B. 2026-06-10 세션 변경 요약 — SNS 자동화 + 어드민 가게사진

### 메인 앱 (receiptiq)

| build | 내용 |
|---|---|
| **429** | 어드민 가게수정 화면의 가게사진이 안 보이는 버그 안전망 (`onerror` fallback / 사진 클릭 시 새 탭 원본 / console 진단 로그) + 정렬을 「대표 → 최신 등록순」 으로 단순화 + 수동 ↑↓ 정렬 폐지 |
| **430** | 어드민 가게사진을 **`store_photos`(어드민 등록) + `store_community_photos`(유저 등록) 통합 조회**. 각 사진에 「관리자/유저」 출처 라벨. 유저 사진을 대표로 지정하면 `store_photos` 에 자동 복사 후 `is_primary=true` (원본은 양쪽에 그대로). 삭제는 각 출처 테이블 + Storage 파일 모두 |

`_admLoadStorePhotos / _admTogglePrimaryPhoto / _admDeleteStorePhoto` 가 `source` 인자(`'admin'` | `'community'`) 받음.

### 블로그 (retwork-blog) — **`SMW-Code/retwork-blog` 별도 레포**

1. **X (트위터) 자동 게시** — `/api/sns/x/route.ts` 신설, `twitter-api-v2` 패키지
   - 발급 후 Vercel 환경변수 4개 등록: `X_API_KEY` / `X_API_SECRET` / `X_ACCESS_TOKEN` / `X_ACCESS_TOKEN_SECRET`
   - 280자 자동 메시지 + 「메시지 직접 작성하기」 옵션
   - **트위터 자체 무료 plan 폐지**됨 → pay-per-use 크레딧 필요 (월 1500건은 충분)
   - App permissions 「Read and write」 필수 (Read-only 면 403)
   - 수정 모드에선 기본 OFF (같은 트윗 중복 시 403 Duplicate)
2. **Threads 자동 게시** — `/api/sns/threads/route.ts` 신설
   - `THREADS_USER_ID` / `THREADS_ACCESS_TOKEN` 2개 환경변수
   - Meta Developer 앱 → 「Threads API 액세스」 use case → Threads 테스터 추가 → Long-lived token 발급
   - 2단계 게시 (컨테이너 생성 → publish), 500자, URL 단축 없음
3. **공통 모듈** `lib/sns.ts` — `formatTweet` / `formatThread` / `postToX` / `postToThreads` + 결과 타입. 기존 `/api/sns/x`, `/api/sns/threads` 도 이걸 사용하도록 리팩토링
4. **기존 글 재공유 endpoint** `/api/sns/share-by-slug/route.ts`
   - 입력: `{ password, slug, platforms?: ['x','threads'], customX?, customThreads? }`
   - 인증: `ADMIN_PASSWORD` **또는** `BLOG_PUBLISH_KEY` (별도 게시키, 옵션)
   - 글 목록 UI 에 `[X] [Threads] [X + Threads]` 3 버튼 추가 (이모지에서 텍스트로 교체)
   - curl 한 줄로 외부 자동화 가능
5. **이미지 회전·자르기** — Canvas 기반 모달
   - 대표 이미지 / 이미지 블록 둘 다에 「✂️ 회전·자르기」 버튼
   - 회전: 좌 90° / 우 90° / 180° / 초기화
   - 비율: 원본 / 1:1 / 4:3 / 16:9 / 3:2 / 3:4 / 9:16 (중앙 자동 자르기)
   - 적용 시 Canvas.toBlob → JPEG q0.9 → 새 File
6. **이미지 자동 압축** (가장 중요한 픽스) — `compressImage(file, 1600, 0.85)`
   - 「Request Entity Too Large (413)」 → 클라가 받은 HTML 을 `.json()` 으로 파싱하다 `"Unexpected token 'R', \"Request En\"..."` 에러 발생
   - 원인: base64 인코딩 시 1.33배 → Vercel API Route 4.5MB 한계 초과
   - 픽스: 파일 선택 직후 1600px / JPEG 85% 로 자동 변환 → 5MB → 200~500KB
   - `pickHero` / `setBlockFile` async 화
7. **6편째 블로그 글**: `nagi-niboshi-jimbocho.md` (神保町 すごい煮干ラーメン凪 정직 후기 ★★★☆☆+)

관련 commit (retwork-blog):
- `45e1206` 이미지 회전/자르기
- `d2dd3fe` 이미지 자동 압축
- `15dcdac` SNS 버튼 이모지→텍스트
- `5d7a6ac` nagi 블로그 글
- `7a6862b` X 자동 게시 신설
- `862609e` Threads 자동 게시
- `ad16d39` share-by-slug + 글목록 SNS 버튼 + BLOG_PUBLISH_KEY 인증

## 0-A. 이번 세션(2026-06-09) 변경 요약 — 인프라/콘텐츠

코드 빌드(428)는 다른 PC 에서 작업되었고, 이 PC 에서는 **운영자 정보 / 도메인 메일 / DNS** 정리 작업 진행:

| 영역 | 변경 |
|---|---|
| 도메인 DNS | Onamae → **Cloudflare** 로 네임서버 이전 (`bart/fiona.ns.cloudflare.com`) |
| Vercel 레코드 | A `retwork.jp` / CNAME `blog`, `www` **모두 프록시 OFF** (회색 구름) — Vercel과 Cloudflare 프록시 같이 켜면 충돌 |
| 도메인 메일 | **Cloudflare Email Routing** 활성화 → `info@retwork.jp` → 본인 Gmail 로 포워딩 |
| Gmail 발신 | "다른 주소로 메일 보내기" 등록 (SMTP `smtp.gmail.com:587` + Google **앱 비밀번호**) — 답장도 `info@retwork.jp` 발신 가능 |
| 운영자 익명화 | `SEO MINWOO` → `RetWork 編集部` (15개 파일 / 36개 위치) — `about/contact/privacy/terms/index` + blog 11편 |
| 연락처 익명화 | `minwoo.seo1019@gmail.com` → `info@retwork.jp` 전부 |
| 모킹 페이지 | `민/민우님` → `ゲ/ゲストユーザー` (prototype, home-mockup, design-compare) + 한국어 한 줄 → 일본어 |
| robots.txt | `/prototype.html`, `/home-mockup.html`, `/design-compare.html`, `/design-preview.html`, `/color-preview.html`, `/report-mock.html` 색인 차단 |
| ads.txt | 이미 정상 (`google.com, pub-6495876616577319, DIRECT, f08c47fec0942fa0`) — AdSense 인식 대기(24~48h) |

관련 커밋:
- `e4ec3bb` — 운영자/이메일 일괄 교체 (15개 / 36 위치)
- `d407275` — 모킹 페이지 익명화 + robots.txt 차단

---

## 0. 프로젝트 한눈에

- **단일 파일 PWA**: `public/index.html` (~25,000 lines) + `public/sw.js`
- **API routes**: `app/api/{vision,gpt,push,cron,resolve-gmap}/route.ts` (Next.js 16 App Router, Node runtime)
- **백엔드**: Supabase (Postgres + Auth + Storage + Realtime)
- **배포**: Vercel 자동 (`main` push → 즉시 반영)
  - **메인 앱**: 프로젝트명 `ret-work`, Root Directory = repo root, 도메인 retwork.jp
  - **블로그**: 프로젝트명 `retwork-blog`, Root Directory = `blog`, 도메인 blog.retwork.jp
- **모드**: ReceiptIQ (가계부) ↔ チリつも (가성비 맵)
- **i18n**: 4언어 (ja / ko / en / zh) — `data-i18n` 속성 + `I18N` 객체 + CMS

### ⚠️ Vercel 빌드 함정 (한 번 데였음)

저장소 root 의 `tsconfig.json` 은 **반드시 `"exclude": ["node_modules", "blog"]`** 유지.
이유: 메인 앱 (`ret-work`) Vercel 빌드가 `blog/*.ts` 까지 type check 하면서
`gray-matter` 등 blog 의존성을 못 찾아 빌드 실패. b384~b388 + 모든 블로그 커밋이
**8시간 동안 prod 배포 못 됨**의 진짜 원인이었음 (commit a639f3f 로 픽스).

블로그 폴더에 새 ts/tsx 파일을 추가해도 메인 빌드가 안 깨지는지 항상 Vercel 대시보드에서 한 번 확인할 것.

---

## 1. 빌드 / 캐시

```
public/index.html → window.__APP_BUILD__ = 456;
public/sw.js      → CACHE_NAME = 'receiptiq-v0.9.0-b469';
```
> ⚠️ 빌드 시 **두 곳 모두** 같은 번호로 올릴 것 (안 맞으면 SW 캐시 갱신 안 됨).
> 인라인 스크립트 문법 검증: `node -e "...new Function..."` (배포 전 습관).

### build 404 — 어드민 모바일도 PC 타입(반응형)으로 통일
- `openAdminDashboard`: 너비 768px 분기 제거 → **모바일·PC 모두 `openAdminPc()`**. 모바일 시트(ov-admin)는 미사용.
- 반응형 CSS(≤767px): 톱바 탭 `#apc-tabbar` 가로스크롤, 본문 `#apc-body` 세로스택, 사이드바 `#apc-sidebar`를
  240px 세로 → **상단 가로 스크롤 띠**(칩 형태 `.apc-menu-item`), 섹션헤더 숨김, 이메일 숨김, 패딩 축소.
- 마크업 id 추가: apc-topbar/apc-logo/apc-tabbar/apc-body. `_isAdminPcActive`는 ov-admin-pc 표시여부만 봐서 자동 호환.

### build 403 — 광고 시청 게이트 버튼 문구 컨텍스트별로
- `watch-ad-primary-btn` 라벨이 항상 "광고 보고 내용 확인하기"였던 것 → 컨텍스트 `base.descTitle` 사용(16003).
  치리 공개=「광고 보고 치리에 공개하기」, 저장=「…가계부에 무료 저장」 등 자동.

### build 402 — 어드민 가격핀 코멘트 전용 삭제
- 가격핀 카드에 **"💬 삭제"**(코멘트만, 핀/마커 유지 = `_admPcClearPinComment` UPDATE comment='') 추가. 기존 "삭제"→"핀 삭제"로 명확화.
- 미해결(분석 중): 새로고침 시 마지막 화면 복원 안 됨(_restoreNav/_loadSavedNav sessionStorage 로직), 전체화면 모달에서 PTR 비활성(25918 `.bottom-sheet-overlay` disarm).

### build 401 — 어드민 가격핀 닉네임 + 댓글삭제 RLS 무효 감지
- 어드민 가게핀 상세(`_admPcOpenPinStoreView`): 가격핀 카드의 `UID:xxx` → **작성자 닉네임**(profiles 조회 `_pinNick`). 메뉴이름/가격은 유지.
- `_admPcDeleteComment`: `.delete().select()`로 실제 삭제행 확인 → **0건이면 RLS 막힘 경고**(조용한 no-op 방지).
- ★ 가게코멘트 삭제가 유저페이지에 반영 안 되던 원인 = `store_comments_admin_delete` RLS 미적용 추정 →
  **Supabase에 `admin_rls_policies.sql` 실행 필요**. (또는 price_pins.comment 복사본은 build 400 이전 데이터에 잔존)

### build 400 — 가격핀 코멘트를 가게코멘트→메뉴별 코멘트로
- `submitChiriPublish` newPins의 `comment`를 공통 `commentText`(가게 코멘트) → **그 메뉴의 코멘트 `item.cpComment`** 로 변경.
  어드민 가격핀에 모든 핀이 같은 가게코멘트로 복제되던 문제 해결(메뉴 이름↔코멘트 일치). 가게 코멘트는 store_comments에만.

### build 399 — 치리 공개 코멘트 문구 명확화
- 메뉴 코멘트 placeholder: "このメニューについてコメントを書いてください". 가게 코멘트: 라벨 "💬 お店についてのコメント" 추가 + placeholder "お店全体について…". (어느 대상 코멘트인지 직관적으로)

### build 398 — 치리 공개: 메뉴별 코멘트 추가
- 품목 프리뷰 각 행에 코멘트 input(`cpSetItemComment`→`it.cpComment`, 재렌더 안 함). `submitChiriPublish`에서
  `store_menu_comments.content=_mC`(평점 없어도 코멘트만 있으면 insert, rating은 null 허용). 메뉴별 코멘트도 차단어 검사.
- 하단 cp-comment(가게 단위 코멘트)는 그대로 store_comments에 저장(별개). ⚠️ store_menu_comments.rating NOT NULL이면 코멘트-only insert 실패 가능(catch됨) → 필요시 컬럼 nullable로.

### build 397 — 치리 공개 모달 개편: 가게사진 + 메뉴별 평점/사진
- `ov-chiri-publish`: 가게명 아래 **가게 사진 첨부**(`cp-store-photo`/`cpPickStorePhoto`→`store_community_photos`).
- 전역 별점 1개 제거 → **품목 프리뷰(`updateCpPreview`)에서 메뉴별 별점**(`cpSetItemRating`, `it.cpRating`) + **메뉴별 사진**(`cpPickItemPhoto`, `it.cpPhotoFile`).
- 사진 첨부 공통: 숨은 input `cp-photo-input`+`cpOnPhotoPicked`, 업로드 헬퍼 `_cpUploadPhoto(file,subdir)`(압축→store-photos 버킷→publicUrl).
- `submitChiriPublish`(async): 가게사진 업로드 → store_comments(평점=메뉴별 평균) → 품목별 루프(사진 업로드+신규/기존 카드 분기, 기존카드 image_url 비면 채우고 아니면 store_menu_photos에 추가, 평점은 store_menu_comments). 중복제출 가드 `_cpSubmitting`+버튼 비활성화.
- DB 변경 없음(store_community_photos/store_menu_photos 기존 테이블 사용). dead code: cpSelectStar/_cpStarRating(미사용).

### build 396 — 설정창 글자 크기(앱 UI 스케일) 기능
- 설정창에 文字サイズ(小/標準/大/特大) 컨트롤(`#font-scale-opts`). `applyFontScale(scale)` → `#app`에 `zoom` 적용.
- 핵심: 인라인 px 폰트라 rem 불가 → **zoom 방식**. `.phone` 높이/폭은 `_syncPhoneVH`에서 **÷scale 보정**(window._fontScale)
  → 전체높이 안 깨짐. localStorage `riq_font_scale`, 시작 시 복원. 기본 1(標準)에선 변화 없음(zero-risk).
- i18n `settings.fontsize` 4언어. ⚠️ 지도(Google Maps)는 zoom 영향권 — 큰 스케일에서 마커 클릭 오프셋 가능(실기기 확인).

### build 395 — 메뉴카드 추가 폼 이모지→SVG
- 가게상세 메뉴카드 추가(`sdOpenAddCard`/`_sdRenderCatPicker`): 대분류 칩(🍣일식…), 🏷️/🍽️/📷 이모지를 SVG 라인 아이콘으로.
- 대분류는 `_SD_CAT1_ICON`(키→ct아이콘키) 매핑 + `_ctCatSvgStr` 사용. **저장값(SD_CATS 키, 이모지 포함)은 그대로** 유지(기존 카드 안 깨짐), 표시만 SVG+라벨(선두 이모지 strip).
- 참고: 저장된 메뉴 카드의 카테고리 문자열엔 여전히 이모지 포함(표시 위치별로 추후 strip 가능).

### build 394 — 어드민 영수증 카테고리 select 이모지 제거(+군것질 추가)
- `adm-rec-cat` select 옵션의 선두 이모지 제거(텍스트만 — `<option>`은 SVG 불가). snack 옵션 추가.
- 참고: 치리톡 음식 카테고리 칩은 이미 `_paintCtCatChips()`(applyLang에서 호출)가 런타임에 SVG로 변환 중이라 변경 불필요. 지도 마커는 의도적으로 이모지 유지.

### build 393 — 수동입력 모달 카테고리 칩 이모지→SVG 라인 아이콘 통일
- 지출 카테고리 시스템 UI를 전부 단색 SVG로 통일(`CAT_ICON`). 수동입력 모달만 이모지였던 것 수정.
- 남은 이모지(미변경): 치리톡 음식 카테고리 칩(ct.cat, 별도 시스템), 어드민 select(`<option>` SVG 불가),
  지도 마커 핀(CAT_EMOJI/CT_CAT_EMOJI, data-URI). 필요 시 후속 작업.

### build 392 — OCR 결과에 지출방법 파싱·선택 + 카테고리 군것질 추가/외식→식사
- **지출방법**: GPT 프롬프트에 `pay`(credit/debit/ic/qr/cash) 판정 규칙+출력필드 추가. `parseWithGPTMulti` 등
  result 빌더 3곳에 `pay:_normPay(result.pay)`. OCR 결과화면(`showOcrResult`)에 지출방법 선택기(`ocr-pay-select`,
  `selectOcrPay`) 추가 — GPT값 pre-select, 사용자 수정 가능. 저장 시 `payment_method:r.pay`(기존 null 하드코딩 수정).
- **카테고리 snack(군것질·과자)** 신규: `_CAT_ICON_PATHS`(cookie)/`CAT_EMOJI`(🍪)/`_CAT_LABEL_KEYS`/i18n 4언어
  (`cat.snack`) + OCR allCats + 수정/수동 모달 cats 배열에 추가.
- **외식→식사**: `cat.eat` 값 변경 (ja 食事/ko 식사/en Meal/zh 用餐). 키는 'eat' 그대로(집계 로직 안 깨짐).

> ⚠️ 어드민 가격핀→어드민 편집 회귀수정(구 build 391)은 `backup-b391-395` 브랜치에 보관됨. 추후 재적용 예정.

### build 391 — 영수증 수정 품목 행 레이아웃 수정
- 영수증모드 > 내역 > 지출카드 > 수정 시 품목 행이 가로 넘쳐 X(삭제)버튼이 잘리던 문제.
- `renderEditItems()` (index.html ~7682): 가격칸 `flex:1`→**고정 76px**(우측정렬), 이름칸 `flex:1+min-width:0`,
  수량칸 40px, 전 입력칸 `box-sizing:border-box` → 한 화면에 다 들어오고 X 항상 표시.

### build 390 — 가게목록 펼침 영역 좌측 쏠림 수정
- `.shop-card`가 `align-items:flex-start`라 펼침 detail이 내용폭만 차지 → 좌측 쏠림.
- `#{sId}-detail` 에 `width:100%;box-sizing:border-box;` 추가 → 카드 전체폭 사용.

### build 389 — 위치수정 요청 (가게목록 직접편집 → 요청 모델) ★ SQL 실행 필요
**`store_edit_requests_kind.sql` 실행 필요** (store_edit_requests 에 `kind` 컬럼 추가).
- 가성비맵 가게목록: 직접 위치수정(`startManualPin`) 버튼 **삭제**. 카드 펼침 영역에 **📍 位置修正をリクエスト** 버튼 추가.
  no-pin 가게도 펼쳐지게 `toggleStoreCard()` 추가(지도이동 없이 토글), chevron 항상 표시.
- 요청 모달은 기존 `ov-store-edit-req` **재사용** — `window._serReq={kind,store_name,lat,lng}` 컨텍스트로
  일반(`sdReqEdit`) / 위치(`reqStoreLocationEdit`) 분기. `submitStoreEditReq()`가 kind 포함 insert
  (kind 컬럼 없으면 자동 재시도로 graceful).
- 어드민: 기존 "가게 수정요청" 옆에 **"📍 위치수정 요청"** 카드 추가. 같은 모달 `ov-admin-edit-reqs`를
  `_setEditReqKind(kind)`로 제목/필터 전환(kind는 **클라에서 필터** → 컬럼 없어도 안 깨짐).
  배지 2개(`adm-editreq-badge`/`adm-locreq-badge`), PC드릴다운 `editreqs`/`locreqs` 항목.

**캐시 정책**: HTML 은 네트워크 우선 (`no-store`), 나머지 정적 자원은 캐시 우선. 사용자에게는 항상 `Ctrl+Shift+R` 강제 새로고침 안내. PWA 설치된 경우 앱 종료 후 재시작.

### build 388 — Google 지도 단축 링크 자동 좌표 추출
- 새 API: `app/api/resolve-gmap/route.ts` (Node runtime)
  - `maps.app.goo.gl` / `goo.gl` 단축 URL → server-side fetch (redirect:'follow') → 최종 URL 의 좌표 추출
  - SSRF 방지: Google 도메인 화이트리스트
  - 모바일 UA 헤더로 정확한 redirect 유도
- 클라이언트 `_admGmapUrlChanged(url)` (in `index.html` ~23710):
  - 정식 링크 → 즉시 정규식 추출 (`@lat,lng` / `!3d!4d` / `?q=` / `?ll=`)
  - 단축 링크 → `/api/resolve-gmap?url=...` 호출 → 좌표 받아 동기화
  - `_admApplyExtractedLatLng()` 헬퍼로 lat/lng input + 마커 + 지도 panTo + 토스트
  - 중복 호출 차단: `_admGmapLastExtractedKey`, `_admGmapShortResolvedFor`

### build 387 — 정식 Gmap URL 자동 좌표 추출 (b388 의 1단계)
- 가게 편집 UI 의 `adm-store-gmap` input 에 `oninput` 핸들러 추가
- `_admExtractLatLngFromGmapUrl()` 정규식 함수
- `openAdminStoreDetail()` 진입 시 캐시 키 reset

### build 386 — 가게 그룹 카드 onclick 안전 escape
- `index.html` 라인 ~13172 의 `_toggleStoreItems` / `flyToStoreFromHistory` 호출
- `_attrArgs(...)` 헬퍼: `JSON.stringify` → `.replace(/"/g,'&quot;')` 통일
- b384 와 같은 종류 잠재 위험 일괄 정리

### build 385 — 메뉴 사진 출처 시트 z-index
- `#ov-store-detail` (z-index:980) 가 stacking context 형성 → `#ov-photo-source` (기본 .overlay 500) 가 뒤로 깔리던 버그
- CSS: `#ov-photo-source{z-index:1100;}` (라인 628 근처)
- JS: `sdStartCardPhoto` 의 `openOv` 직전에 `document.body.appendChild(ps)` 트릭 (다른 모달 패턴과 통일)

### build 384 — 영수증 내역 마ップで見る 버튼 SyntaxError
- 라인 7373: `onclick="...flyToStoreFromHistory("X","Y",...)"` 에서 JSON.stringify 결과의 `"` 가 attribute 종료 따옴표와 충돌
- 인자들을 `JSON.stringify().join(',').replace(/"/g, '&quot;')` 로 처리

### build 383 — 사진 업로드 자동 압축 + 메뉴 카드 사진 prefetch
- `_compressImage(file, maxDim, quality)` 헬퍼 (Canvas 기반)
- 메뉴 카드/가게 사진 업로드 시 자동 압축

### build 382 — 출석 토글 localStorage 캐싱
- `att_push_optin`, `att_push_row_visible` — 설정창 진입 시 깜빡임 제거

### build 380-381 — 코스파맵 주변 미방문 가게 마커
- `_ctShowUnvisitedMarkers` — 현재 위치 기준 반경 내 가게 중 사용자 미방문 가게를 별도 색 마커로 표시

### build 379 — 가게 상세 모달 전체창 전환 (이전 핸드오프 시점)
- 바텀시트(92vh) → 전체창. CSS `#store-detail-panel`: border-radius:0, height/max-height:100%
- `#sd-header` 상단 sticky + safe-area-inset-top, 좌측 ‹ 뒤로가기 버튼

---

## 2. Supabase 스키마 (현재 적용된 핵심 테이블)

| 테이블 | 핵심 컬럼 | 용도 |
|---|---|---|
| `profiles` | id, nickname, is_admin, budget_amount, budget_month, deleted_at | 사용자 |
| `receipts` | id, user_id, store_name, receipt_date, total_amount, lat, lng, store_address | 영수증 |
| `items` | id, receipt_id (FK CASCADE), name, quantity, price, category, product_id | 영수증 품목 |
| `stores` | id, name, lat, lng, category, avg_price, receipt_count, google_maps_url, featured_price, featured_menu_name | 가게 |
| `price_pins` | id, store_id, item_name, price, comment, user_id | 가성비 핀 (치리 공개) |
| `store_menu_cards` | id, store_name, menu_name, price, category, image_url, is_featured, rating_avg, rating_count, sort_order | 메뉴 카드 |
| `store_menu_photos` | id, menu_card_id (FK CASCADE), image_url, is_primary, sort_order, uploaded_by | 메뉴 추가 사진 |
| `store_menu_comments` | id, menu_card_id (FK), user_id, rating, content, updated_at — UNIQUE(menu_card_id, user_id) | 메뉴별 평점/댓글 |
| `store_menu_replies` | id, comment_id (FK), user_id, content | 메뉴 댓글 답글 |
| `store_comments` | id, store_name, user_id, user_name, content, rating, has_receipt | 가게 단위 방문자 리뷰 |
| `store_photos` | id, store_name, photo_url, user_id, is_primary, sort_order | 가게 사진 (어드민) |
| `store_community_photos` | id, store_name, photo_url, uploaded_by | 가게 사진 (유저 등록) |
| `announcements` / `store_items` / `comment_reports` / `banned_words` / `banned_users` | — | 공지/스토어/신고/제재 |
| `coin_transactions` / `ad_views` | — | 보상/광고 |
| `products_master` | id, name, normalized_name, ... | GPT 정규화 상품 |
| `store_edit_requests` | — | 가게 수정 요청 (사용자) |
| `private_notes` | — | 가게별 비공개 메모 |
| `i18n_translations` | key, ja, ko, en, zh | i18n CMS |
| `web_push_subscriptions` | id, user_id, endpoint, p256dh, auth | Web Push 구독 |
| `admin_messages` | id, recipient_id, title, content, ... | 어드민 → 유저 쪽지 |

### 적용한 SQL 파일들 (`./*.sql`)

- `store_photos.sql` — 사진 관련 테이블 (idempotent v3, store_name 기반)
- `admin_rls_policies.sql` — 어드민 INSERT/UPDATE/DELETE + 본인 정책
- `merge_duplicate_menu_cards.sql` — 메뉴 카드 통합 사례 (참조용, 1회성)
- `dedupe_menu_comments.sql` — 댓글 content 중복 정리 (참조용)
- `profiles_budget.sql` — 예산 컬럼 추가

### Supabase Storage Bucket

| Bucket | Public | 용도 |
|---|---|---|
| `store-photos` | ✅ | 가게 / 메뉴 / 커뮤니티 사진 (5MB, image/*) |
| `receipts` (기존) | ✅ | 영수증 이미지 |

Storage 정책: SELECT 누구나, INSERT/UPDATE/DELETE 는 본인 또는 어드민.

---

## 3. 블로그 (blog.retwork.jp) — AdSense 통과용

- 위치: `blog/` 폴더 (별도 Next.js 15 + Markdown + gray-matter)
- 폴더 구조:
  - `blog/app/{layout,page,about,privacy,terms}/page.tsx` (인라인 CSS via `dangerouslySetInnerHTML`)
  - `blog/app/posts/[slug]/page.tsx` (`generateStaticParams` + force-static)
  - `blog/app/{robots.txt,sitemap.xml}/route.ts`
  - `blog/lib/posts.ts` (gray-matter + remark)
  - `blog/posts/*.md` — frontmatter (title/date/description/image/tags/author)
  - `blog/public/images/<slug>/*.jpg` — 사진 (자동 압축됨)
  - `blog/scripts/compress-images.js` — sharp 기반 일괄 압축 (1600px, q78, mozjpeg)

### 운영 흐름

```bash
# 새 글 작성
cd blog
# 1. blog/posts/<slug>.md 작성 (frontmatter + 본문)
# 2. blog/public/images/<slug>/ 폴더에 사진 저장
# 3. 압축
node scripts/compress-images.js public/images/<slug>
# 4. push (Vercel 자동 배포)
git add blog/posts/<slug>.md blog/public/images/<slug>/
git commit -m "blog: add <slug>"
git push
```

### 현재 글 목록 (5편 / AdSense 권장선 도달)

| # | slug | 카테고리 |
|---|---|---|
| 1 | `kitakata-shokudo-jimbocho` | 음식점 후기 |
| 2 | `chogori-jimbocho` | 음식점 후기 |
| 3 | `retwork-app-guide` | 앱 가이드 |
| 4 | `how-to-keep-kakeibo` | 라이프해크 |
| 5 | `analyze-food-habits-from-receipts` | 데이터 분석 |

### 인프라

- Search Console: 소유권 인증 OK (`blog/public/google4a48c85cc102d622.html`)
- Sitemap 제출 완료
- DNS: 오나마에닷컴 CNAME `blog → cname.vercel-dns.com`
- AdSense: 미신청 (5편 + 며칠 색인 안정화 대기)
- 환경변수: `NEXT_PUBLIC_ADSENSE_CLIENT` 비어 있음 (AdSense 승인 후 설정)

---

## 4. SVG 아이콘 시스템 (`window.__LICO_SET__`)

라인 ~24825. 50+ Lucide-style stroke SVG. 사용:

```js
icon('camera', 26, 'var(--green)')  // 인라인 SVG 문자열 반환
```

또는 마크업으로:
```html
<span class="lico" data-lico="camera" data-size="20" data-color="var(--text-2)"></span>
```

`_renderLicos()` + MutationObserver 가 자동 변환.

---

## 5. 주요 흐름

### 영수증 OCR → 저장
1. 카메라/이미지 선택 → `/api/vision` (Node runtime, GPT Vision)
2. `result.date` 는 **원본 표기** ("26年6月4日", "平成26年6月4日") — build 346 부터 GPT 환산 X
3. 클라이언트 `_sanitizeReceiptDate` 가 5가지 패턴 처리 (元号/2자리/4자리/ISO)
4. OCR 결과 화면에 가게명/날짜(input type=date)/카테고리/품목/총액 편집
5. 저장 흐름:
   - **가계부에 저장하기** → `_doSaveOcrResult()` (광고 → receipts insert)
   - **가계부 저장 ＆ 치리츠모 공개** → `_doSaveOcrResult()` (즉시) + `openChiriPublish()` 모달 → `submitChiriPublish()` (price_pins insert + store_menu_cards 중복 방지)

### 가게 상세 모달 (`ov-store-detail`) — z-index 980, 전체창
- 헤더 → 사진(H=244px) + 사이드 4 버튼 → Google 정보 → 광고 → 메뉴 카드 → 방문자 리뷰 → 비공개 메모
- 사이드 4 버튼: 📷(camera) / 🗺️(map_pin) / 🌐(globe) / 📤(share)
- 점점점 메뉴: 수정 요청 / 닫기
- 이 모달이 stacking context 형성 → 그 위에 띄울 모달은 z-index 1000+ + body 마운트 트릭 필요

### 어드민 가게 편집 모달
- 위치: `ov-admin-edit-store`
- 필드: 이름 / 카테고리 / lat / lng / google_maps_url / 미니맵 (drag 가능한 마커)
- **google_maps_url 입력 → 좌표 자동 추출** (b388):
  - 정식 링크: 즉시 정규식
  - 단축 링크: `/api/resolve-gmap` 서버 fetch
  - 마커 + lat/lng input 동시 갱신

### 사진 슬라이드 + 전체화면 뷰어
- 가게 사진: `store_photos` + `store_community_photos` 통합, 대표 우선
- 메뉴 카드 사진: `store_menu_cards.image_url` + `store_menu_photos`
- 뷰어: `ov-sd-photo-viewer` (z-index 99999, body 마운트), ‹/›/✕/Esc + 키보드

### 어드민 PC 모드
- `_admPcDrilldownTo(modalId, opts)` → 시트를 콘텐츠 영역에 마운트
- 가게 편집 모달 / 메뉴 카드 수정 / 가게핀 페이지 등

---

## 6. Web Push (build 306~)

- VAPID 키: Vercel 환경변수 `VAPID_PUBLIC_KEY` / `VAPID_PRIVATE_KEY`
- 구독: `/api/push/subscribe`
- 발송: `/api/push` (cron + 운영팀 메시지)
- GitHub Actions cron — `.github/workflows/attendance-push.yml` (출석 슬롯 8:00/16:00 JST)
- TWA APK: PWA Builder, package=`jp.retwork.app`, SHA-256 등록 (`/public/.well-known/assetlinks.json`)

---

## 7. 최근 build 흐름 (379~388)

| build | 내용 |
|---|---|
| **379** | 가게 상세 모달 전체창 전환 |
| **380-381** | 코스파맵 주변 미방문 가게 마커 |
| **382** | 출석 토글 localStorage 캐싱 (깜빡임 제거) |
| **383** | 사진 업로드 자동 압축 + 메뉴 카드 사진 prefetch |
| **384** | 영수증 내역 マップで見る onclick SyntaxError 픽스 |
| **385** | 메뉴 사진 출처 시트 z-index/body 마운트 |
| **386** | 가게 그룹 카드 onclick 안전 escape (재발 방지) |
| **387** | 어드민 Gmap URL → 정식 링크 좌표 자동 추출 |
| **388** | 어드민 Gmap URL → 단축 링크도 자동 추출 (`/api/resolve-gmap`) |
| (commit) | `a639f3f` — tsconfig 에 blog exclude — Vercel 빌드 정상화 |

---

## 8. 다음 작업 후보

### 앱
- 어드민 가게 편집: 단축 링크 자동 추출 검증 + 좌표 추출 실패 시 fallback UX 개선
- 메뉴 카드 순서 배열 — 어드민 드래그/↑↓로 sort_order 설정
- 다국어 미적용 라벨 발견 시 i18n CMS (`openAdminI18n`)
- 가게 상세 모달 디자인 미세 조정

### 블로그
- 6편째 글 후보:
  - C. 神保町 가성비 음식점 큐레이션 (지금 2곳 + 街ガイド)
  - G. 「節約レシピ・買い物リスト術」 일반론
  - I. PWA 가계부 vs 네이티브 앱 비교
  - 직접 다른 가게 영수증/사진 받으면 후기 추가
- 며칠 색인 안정화 후 AdSense 신청
- AdSense 승인되면 `NEXT_PUBLIC_ADSENSE_CLIENT` 환경변수 설정

---

## 9. 환경 / 명령

### 로컬 개발
```bash
cd C:\Users\minus\Desktop\receiptiq
npm run dev               # 메인 앱 (Next.js 16, port 3000)

# 블로그
cd blog
npm run dev               # 블로그 (Next.js 15, port 3001)
```

### 배포
```bash
git push                  # main 푸시 → Vercel 두 프로젝트 모두 자동 배포
```

### Supabase
- 프로젝트: `fkvfbxfgidrvymoftkdd.supabase.co`
- SQL Editor 에서 `./*.sql` 파일 실행
- Storage Dashboard 에서 `store-photos` bucket 관리

### Vercel
- 메인 앱: https://vercel.com → `ret-work` 프로젝트
- 블로그: https://vercel.com → `retwork-blog` 프로젝트
- **항상 push 후 1-2분 안에 Vercel Deployments 에서 Ready 인지 확인** (b384~b386 8시간 빌드 실패 사건 재발 방지)

---

## 10. 자주 쓰는 디버깅 console 로그

```
[chiri-publish] 가계부 저장 시작 (광고 모달 전)
[chiri-publish] menu_cards: new=N, existing=N
[admLoadStoreMenus] 정확 매칭 / fuzzy 후보 / 최종 표시
[admPcEditMenuCard] 정확 매칭 / fuzzy 매칭 성공
[admLoadMenuPhotos] legacy=... | siblings=...
[admPcLoadStoreMenuCards] storeName → N개
[admPcDeletePin] 삭제된 행 수
[sdSubmitComment] store_comments 동기화 시도
[sdSubmitComment] store_comments updated: N
[receipt date] 5+ years past — 확인 필요
[resolve-gmap] (b388) 단축 링크 해석 실패/성공
```

---

## 11. RLS / 보안 패턴

- `auth.uid()` 기반 본인 정책
- 어드민: `EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE)`
- 모든 INSERT/UPDATE/DELETE 코드에 `.select()` + length 검증 추가 (RLS 차단 시 사용자에게 명시적 알림)
- 새 테이블 추가 시 `admin_rls_policies.sql` 에 정책 추가하는 패턴
- 새 서버 API route 추가 시 SSRF/도메인 화이트리스트 (예: `app/api/resolve-gmap` 의 ALLOWED_HOSTS)

---

## 12. 데이터 정리 유틸 SQL (수동 1회성)

- `./merge_duplicate_menu_cards.sql` — 메뉴 카드 통합 (특정 가게)
- `./dedupe_menu_comments.sql` — 같은 user + content 중복 댓글 NULL 처리

필요 시 사용. 다음 사용자 인스턴스도 동일 케이스 발생하면 비슷한 패턴으로 작성.

---

## 13. 핵심 함정 / 재발 방지 체크리스트

매번 push 후 다음 확인:

- [ ] Vercel `ret-work` 프로젝트 Deployments 의 가장 위 줄이 🟢 Ready 인가? (Error 면 즉시 빌드 로그 확인)
- [ ] `tsconfig.json` 의 exclude 에 `blog` 가 있는가?
- [ ] 새 onclick 핸들러를 inline 으로 만들 때 `JSON.stringify` + `&quot;` escape 패턴 따랐는가? (`_attrArgs` 헬퍼)
- [ ] 새 모달이 `#ov-store-detail`(z-index 980) 위에 떠야 한다면 z-index ≥ 1000 + body 마운트 트릭 적용했는가?
- [ ] 새 서버 API route 추가 시 SSRF / 인증 / rate-limit 고려했는가?
- [ ] 블로그 폴더에 새 ts/tsx 추가 시 메인 빌드 안 깨지는지 Vercel 확인했는가?

---

## 14. 작업 일지 (build 380~388)

- 코스파맵 주변 미방문 가게 마커 추가 (380-381)
- 출석 토글 캐싱 (382)
- 사진 자동 압축 (383)
- **블로그 인프라 구축 + 5편 작성**: 패키지/도메인/Search Console/sitemap 완료
- **Vercel 빌드 8시간 실패 사건**: blog/lib/posts.ts type check 충돌 → tsconfig exclude 추가로 해결
- 영수증 マップで見る SyntaxError + z-index + 가게 그룹 카드 escape 픽스 (384-386)
- 어드민 가게 편집의 Gmap URL → 좌표 자동 추출 (정식/단축 둘 다, 387-388)

---

## 15. 작업 일지 (build 389~428, 다른 PC 작업분)

| build | 내용 |
|---|---|
| **389** | 위치수정 요청 모델 (가게목록 직접편집 → 요청) ★ `store_edit_requests_kind.sql` 실행 필요 |
| **390** | 가게목록 펼침 영역 좌측 쏠림 |
| **391** | 영수증 수정 품목 행 레이아웃 (X 삭제 항상 표시) |
| **392** | OCR 에 지출방법 파싱·선택 + 카테고리 `snack` 추가 + `外食→食事` |
| **393~395** | 카테고리 아이콘 이모지→SVG 통일 |
| **396** | 설정창 글자 크기 (zoom 방식) |
| **397~400** | 치리 공개 모달 개편 (가게사진 + 메뉴별 평점/사진/코멘트) |
| **401~402** | 어드민 가격핀 닉네임 표시 + 코멘트 전용 삭제 |
| **403** | 광고 시청 게이트 컨텍스트별 문구 |
| **404** | 어드민 모바일도 PC 타입(반응형) |
| **405** | 어드민 topbar 버전/빌드 표시 |
| **406** | 치리톡 게시글 → 전체화면 상세 + 이미지 히어로 |
| **407~414** | 새로고침 위치 복원 버그 (여러 라운드) |
| **409** | SW 자동 업데이트 + 새 버전 적용 시 자동 리로드 |
| **415** | nav 진단 패널 제거 |
| **416** | 회귀/죽은코드/중복 정리 |
| **417** | 치리톡 좋아요 멱등성 (`ct_post_likes` + 토글 RPC) |
| **418** | 치리톡 공지 카드 어드민 관리 (`ct_notices`) |
| **419** | 치리토크 베스트(인기) 게시글 자동+수동 (`ct_posts_best`) |
| **420** | 인기글 배너 카드 이미지 URL 텍스트 렌더 픽스 |
| **421** | 치리토크 알림 = 서버 RPC 로만 생성 (보안) |
| **422** | 댓글 수 동기화 + 어드민 가게 삭제 |
| **423** | 알림 분류 픽스 (좋아요/댓글이 시스템 탭 가던 문제) |
| **424~425** | 앱 아이콘 재교체 + 파비콘 |
| **426** | 영수증 원본 이미지 보관 + 어드민 OCR 검수 |
| **427** | 어드민 OCR 검수 ZIP 다운로드 |
| **428** | 자동배포 동작 확인 |

### ⚠️ 다른 PC에서 작업 시 실행 필요한 SQL

- `store_edit_requests_kind.sql` (b389)
- `ct_post_likes.sql` (b417)
- `ct_notices.sql` (b418)
- `ct_posts_best.sql` (b419)
- `ct_admin_moderation.sql` (b421)
- `ct_comment_count_sync.sql` (b422)
- `notify_post_author.sql` (관련 알림 RPC)
- `receipt_images.sql` (b426)

→ 새 PC 에서 작업 전 위 SQL이 Supabase 에 적용되어 있는지 확인.

---

## 16. 도메인 / 메일 인프라 (2026-06-09 신설)

### DNS — Cloudflare

| 레코드 | 콘텐츠 | 프록시 | 비고 |
|---|---|---|---|
| A `retwork.jp` | `216.198.79.1` (Vercel) | **OFF** (회색) | Vercel + Cloudflare 프록시 같이 켜면 충돌 |
| CNAME `blog` | `6d84a6efcce4a...` (Vercel blog) | **OFF** | blog.retwork.jp |
| CNAME `www` | `cname.vercel-dns.com` | **OFF** | www.retwork.jp |
| MX `retwork.jp` × 3 | `route1/2/3.mx.cloudflare.net` | (MX 는 프록시 불가) | Cloudflare Email Routing |
| TXT `retwork.jp` | `v=spf1 include:_spf.mx.cloudflare.net ~all` | — | SPF |
| TXT `cf2024-1._domainkey` | DKIM 키 | — | 메일 인증 |

**🔴 절대 켜지 말 것**: Vercel 레코드(A/CNAME) 의 Cloudflare 프록시 ON → HTTPS 갱신 / Edge 충돌 / 캐시 깨짐.

### 메일 — Cloudflare Email Routing (받기) + Gmail (보내기)

**받기 흐름**:
```
누군가 → info@retwork.jp
       → Cloudflare Email Routing (MX)
       → 본인 Gmail 받은편지함 (minwoo.seo1019@gmail.com 으로 포워딩)
```

**보내기 흐름** (Gmail "다른 주소로 메일 보내기"):
```
Gmail 새 메일 / 답장 → From: info@retwork.jp 선택
                    → smtp.gmail.com:587 + Google 앱 비밀번호로 SMTP 인증
                    → 받는 사람에게 info@retwork.jp 로 표시
```

**주의 — Cloudflare MX 를 SMTP 서버로 쓰면 안 됨**:
Gmail 의 "다른 주소 추가" 시 자동으로 retwork.jp 의 MX (`route3.mx.cloudflare.net`) 를 SMTP 서버로 추측하지만, **Cloudflare Email Routing 은 받기 전용**. SMTP 서버는 `smtp.gmail.com` 으로 수동 변경 필요. (`api_token as username` 에러는 이게 원인)

### 추가 별칭 (필요 시)

Cloudflare 대시보드 → 이메일 → Email Routing → 라우팅 규칙 → "주소 만들기":
- `support@retwork.jp` → 본인 Gmail
- `contact@retwork.jp` → 본인 Gmail
- 또는 **Catch-all** 활성화 → `*@retwork.jp` 모든 주소 본인 Gmail 로

### ads.txt

- 위치: `public/ads.txt`
- 내용: `google.com, pub-6495876616577319, DIRECT, f08c47fec0942fa0`
- AdSense 대시보드의 「찾을 수 없음」 표시는 **AdSense 크롤러 인식 대기** (24~48시간) — 추가 작업 불필요
- 블로그 별도 레포(`SMW-Code/retwork-blog`)에도 동일 ads.txt 필요할 수 있음 (AdSense 에 블로그 따로 등록 시)

---

## 16-B. 블로그 SNS 자동 게시 인프라 (2026-06-10 신설)

### Vercel 환경변수 — `retwork-blog` 프로젝트

| Key | 용도 | 발급처 |
|---|---|---|
| `ADMIN_PASSWORD` | `/admin` 비번 | 본인 정함 |
| `GITHUB_TOKEN` | `/api/publish` 의 GitHub 커밋 | github.com/settings/tokens (Contents:write) |
| `X_API_KEY` | X (트위터) Consumer Key | developer.x.com 의 App |
| `X_API_SECRET` | X Consumer Secret | 동상 |
| `X_ACCESS_TOKEN` | X user-context Access Token | 동상 (App permissions: Read and write 필수) |
| `X_ACCESS_TOKEN_SECRET` | X Access Token Secret | 동상 |
| `THREADS_USER_ID` | Threads 본인 user ID (숫자) | `GET https://graph.threads.net/v1.0/me?access_token=...` 응답의 `id` |
| `THREADS_ACCESS_TOKEN` | Long-lived Access Token (60일) | developers.facebook.com → Threads API 「사용자 토큰 생성기」 |
| `BLOG_PUBLISH_KEY` *(옵션)* | 외부 자동화용 별도 키 | 본인이 32+ 자 랜덤 |

### 함정 / 가르침 받은 점

- **X 무료 plan 폐지** (2024 말~2025) — 이제 무조건 크레딧 구매. 다행히 게시당 비용은 작음 (월 30편이면 매우 저렴)
- **App permissions「Read and write」 필수** — 만약 「Read」 only 면 403. 권한 변경 후 **Access Token 재발급** 필요 (옛 토큰은 옛 권한 그대로)
- **Threads: 콜백 URL 저장 에러는 무시 OK** — 우리는 OAuth flow 안 쓰고 직접 발급된 token 만 사용. 「사용자 토큰 생성기」 → 「Threads 테스터 추가」 → 본인 계정 초대 수락 → 「생성」 으로 Long-lived token 직접 발급
- **Threads 계정 공개(Public) 필수** — 비공개 계정은 token 발급 불가
- **수정 모드에서 X 자동 게시 기본 OFF** — 같은 글의 트윗을 다시 보내면 X 가 403 Duplicate 로 거부. UI 가 자동으로 체크박스 해제
- **이미지 base64 4.5MB 한계** — `compressImage(1600, 0.85)` 가 입력 단계에서 처리. 만약 한계 초과하면 fetch `.json()` 이 HTML(413) 을 파싱 시도하다 `"Unexpected token 'R', \"Request En\"..."` 로 뜸

### SNS 게시 API

```bash
# 단일 SNS 게시 (어드민 발행 시 자동 호출)
POST /api/sns/x
POST /api/sns/threads
{ "password": "...", "title": "...", "description": "...", "url": "...", "tags": [...], "customText"?: "..." }

# 기존 글 재공유 (slug 만으로 자동 메시지 생성)
POST /api/sns/share-by-slug
{ "password": "ADMIN_PASSWORD or BLOG_PUBLISH_KEY",
  "slug": "...",
  "platforms": ["x", "threads"],
  "customX"?: "...", "customThreads"?: "..." }
```

### 운영 흐름

| 상황 | 방법 |
|---|---|
| **새 글 발행** | `/admin` 새 글 → 자동으로 SNS 체크박스 ON → 🚀 발행 |
| **옛 글 재공유** | `/admin` 글 목록 → 글 옆 [X] [Threads] [X + Threads] 버튼 클릭 |
| **외부 자동화** (curl/봇) | `/api/sns/share-by-slug` 호출 (BLOG_PUBLISH_KEY 사용 권장) |

### 글 작성 — admin 에디터 신규 기능 정리 (2026-06-09~10)

- ✂️ 이미지 회전·자르기 모달 (대표 / 블록 둘 다)
- 🎨 글 테마 색상 / 강조 카드 색상 (10테마 + 커스텀 hex)
- ➕ 라인 블록 (구분선)
- 🎨 폰트 스타일 (서체 / 사이즈 / 굵기 / 색상) — heading / text / card 별
- 📄 마크다운 출력 코드뷰 (펼치기/접기)
- 🤖 자동 이미지 압축 (모든 업로드 1600px / JPEG 85)
- 📤 글 목록 SNS 재공유 버튼

---

## 17. Git 워크플로우 — 베타 시점 전환

`origin/dev` 브랜치는 이미 존재. Vercel 이 자동으로 dev → preview URL 생성 중.

### 현재 (베타 전)
```
main ──(직접 푸시)──→ retwork.jp (prod)
```

### 베타 시작 후 (제안)
```
main (freeze, 베타 prod) ──핫픽스만──
  ↑
  ↑ 머지
  ↑
dev ──(개발 푸시)──→ preview URL (또는 beta.retwork.jp)
```

### 베타 시점 전환 절차

```bash
# 1. 베타 시작 직전 — main 동결 + 태그
git checkout main
git tag v1.0-beta -m "Beta release for testers"
git push origin v1.0-beta

# 2. 새 개발은 dev 에서
git checkout dev
git merge main
# 코드 수정...
git push origin dev   # → preview URL 자동 배포

# 3. 베타 핫픽스
git checkout main
# 작은 fix
git push origin main  # → retwork.jp 즉시 반영
git checkout dev && git merge main && git push  # dev 에도 동기화

# 4. 정식 출시
git checkout main
git merge dev
git tag v1.0
git push origin main --tags
```

### 베타 URL 분리 (옵션 — 5분 작업)

베타 테스터에게 일반 사용자와 다른 URL 주려면:

1. Cloudflare DNS → CNAME `beta` → `cname.vercel-dns.com` (프록시 OFF)
2. Vercel → ret-work 프로젝트 → Settings → Domains → `beta.retwork.jp` 추가
3. **Branch** 필드에 `dev` 입력 → 저장
4. → `beta.retwork.jp` 는 dev 빌드, `retwork.jp` 는 main 빌드

### Branch 보호 (옵션)

GitHub Settings → Branches → Add rule → `main`:
- ✅ Require pull request before merging
- ✅ Require status checks (Vercel build pass)

→ 베타 동결 후 실수로 main 푸시 방지. 솔로 개발자라면 거추장스러울 수 있어 선택.

---

## 18. 운영자 / 연락처 표기 통일 정책 (2026-06-09 신설)

본명 / 개인 이메일 노출을 모두 익명화:

| 위치 | 표기 |
|---|---|
| 운영자 | **`RetWork 編集部`** |
| 연락처 메일 | **`info@retwork.jp`** |
| 회사 정보 (소재지) | `東京都中央区晴海（日本）` (유지) |

### 적용된 페이지 (15개 파일 / 36 위치)

- `public/about.html`, `contact.html`, `privacy.html`, `terms.html`
- `public/index.html` (메타 author + JSON-LD + 푸터)
- `public/blog/*.html` (11편 — JSON-LD author + 본문 著者)

### 검색용 명령

향후 본명/개인메일이 새로 들어가지 않았는지 정기 점검:
```bash
grep -rli --exclude-dir=node_modules --exclude-dir=.next --exclude-dir=.git "SEO MINWOO\|minwoo\.seo" .
```
→ 결과 0건이면 OK.

### 모킹 페이지 (검색 차단)

`prototype.html` / `home-mockup.html` / `design-compare.html` 의 더미 텍스트도 `ゲ/ゲストユーザー` 로 익명화 + `robots.txt` 에서 색인 차단.

---

## 19. 다른 PC 에서 이어 작업 시 체크리스트

1. `git pull` (main 최신)
2. **HANDOFF.md 읽기** (이 파일)
3. `npm install` (root)
4. 환경변수 확인 (`.env.local` 또는 Vercel Settings):
   - `GOOGLE_VISION_API_KEY` (또는 `VISION_KEY` 등 대체명)
   - `OPENAI_API_KEY`
   - `VAPID_PUBLIC_KEY` / `VAPID_PRIVATE_KEY`
   - (AdSense 승인 후) `NEXT_PUBLIC_ADSENSE_CLIENT`
5. **Supabase 적용 SQL 확인** (위 §15 의 `ct_*.sql` 등)
6. `npm run dev` 로 build 428 정상 동작 확인
7. 베타 시작 시점이면 → `git checkout dev` 후 작업
8. 메일 보내기 / 받기 테스트 (info@retwork.jp 가 본인 Gmail 로 오는지)

### 도움말 한 줄
- Vercel 대시보드: https://vercel.com/SMW-Code (ret-work / retwork-blog)
- Cloudflare 대시보드: https://dash.cloudflare.com (retwork.jp)
- Supabase: https://supabase.com/dashboard/project/fkvfbxfgidrvymoftkdd
- AdSense: https://www.google.com/adsense
- Search Console: https://search.google.com/search-console

---

## 20. 알려진 미해결 / 분석 중

- **새로고침 후 마지막 화면 복원** — b407~b414 까지 여러 라운드 픽스. 현재 안정적이지만 일부 엣지 케이스 (PWA 백그라운드 종료 후 재시작) 에서 홈으로 복귀 가능성. 추가 사용자 보고 시 분석.
- **store_menu_comments.rating NOT NULL 제약** — 코멘트-only insert 시 실패 가능 (b398). 필요 시 컬럼 nullable 로.
- **store_comments_admin_delete RLS 정책** — Supabase 에 `admin_rls_policies.sql` 실행 안 됐을 가능성 (b401). 어드민 댓글 삭제가 유저 페이지에 반영 안 되면 SQL 재실행.
- **backup-b391-395 브랜치** — 어드민 가격핀→어드민 편집 회귀수정 보관. 필요 시 재적용.
