# i18n(4개국어) 미적용 추적 — RetWork `public/index.html`

> ✅ **2026-06-16 기준 주요 사용자 대면 영역 전부 완료 (build 516~525).** 남은 건 잔여 그룹(아래) 뿐.
> 작성: 2026-06-16 (build 515 조사) / 갱신: build 525 (8개 영역 완료)
> 목적: 일본어 기본값이라 **`data-i18n`/`t()` 누락 시 한·영·중 모드에서도 일본어(또는 하드코딩 한국어)가 그대로 노출**됨. 전수 목록 + 진행상황 추적.
>
> **정책(사용자 확정 2026-06-16):**
> - **어드민**(`adm*`/`admin*`/`apc*`/`ov-admin-*`) → 운영자용 **한국어 고정** (대상 아님)
> - **SEO 랜딩/블로그**(절약·구르메 블로그 검색 노출용, `index.html` 971~1047 마케팅 본문) → **일본어 고정** (대상 아님)
> - **그 외 모든 사용자 대면** → **4개국어 적용** (이 문서의 대상)
>
> 줄번호는 조사 시점(build 515) 기준 **근사값** — 편집하며 이동함. 함수명/요소 id로 찾는 게 정확.

## 처리 방법 (재현용)
- 정적 HTML: `data-i18n="key"`(텍스트) / `data-i18n-placeholder="key"` / `data-i18n-title="key"`. 적용은 `applyLang()`(~14580). **자식 요소(span 등) 있는 컨테이너에 data-i18n 달면 자식이 날아감** → 텍스트만 `<span data-i18n>`로 감싸기.
- 동적 JS(innerHTML/textContent/showToast/placeholder/setAttribute): `t('key', {params})`. `{n}` 보간 지원(`t()` ~14547).
- 키는 `var I18N={ja,ko,en,zh}`(~13448)의 **4블록 모두**에 추가. 한 곳 빠지면 ja로 폴백.
- 카테고리 라벨은 헬퍼 `_cpCatLabel(key)`(ct.cat.* 재사용, 선두 이모지 제거). 카테고리 활성표시는 버튼 `data-cat` 속성 비교(SVG 아이콘 비교 금지).
- **커밋 전**: `node` 문법검사(HANDOFF.md 참고) + 빌드번호 2곳(`__APP_BUILD__`, `sw.js` CACHE_NAME) + 키 4블록 카운트 검증 `grep -oE "'key':" public/index.html | wc -l` == 4.
- 포인트 단위 표기: ja `チリ` / ko `치리` / en `Chiri` / zh `Chiri`.

## 상태 범례
- [x] 완료 (4개국어 적용, 빌드 배포됨)
- [ ] 미처리

---

## ✅ 완료 (build 516~521, 모두 main 배포)

- [x] **치리 공개 모달** `ov-chiri-publish`+`cp*`/`submitChiriPublish` — **b516**. 키 `chiri.pub_*`(15) + `ct.cat.other`. `_cpCatLabel()` 헬퍼 도입.
- [x] **로그인/회원가입** `screen-auth`+`authLogin`/`authSignup`/`switchAuthTab`/소셜로그인 — **b517**. 키 `auth.*`(24, 에러/리다이렉트/생년/성별 등). 기존 `auth.male/female/other/login_btn/signup_btn/password/google` 재사용. (이메일 폼은 현재 display:none 숨김이나 i18n 완료)
- [x] **커뮤니티 가격비교** `fetchAndRenderCommunity`/`_buildStoreCard`/`_statChip`/`_toggleStoreItems`/`_renderItemStats`/`_loadMyVsAvg` — **b518**. 키 `comm.*`(22). `rmap.loading`/`rmap.no_items` 재사용.
- [x] **수동 핀 추가 모달** `ov-manual-pin`/`mp*` — **b519**. 키 `mp.store_name`/`mp.store_ph`/`mp.menu_price`/`mp.add_menu`/`mp.rating`/`mp.menu_name`/`mp.menu_photo`. `chiri.comment_ph`/`publish_btn`/`pub_reward_chip`/`ct.map.category`/`btn.cancel`/`ct.cat.other` 재사용. 카테고리 활성표시 data-cat 기반으로 수정.
- [x] **가게 수정/위치 요청** `ov-store-edit-req`+`reqStoreEdit`/`reqStoreLocationEdit`/`submitStoreEditReq` + 가게탭 힌트(`storeDetailShow`/place-embed-sub) — **b520**. 키 `ser.*`(12) + `sd.tap_hint`. `sd.req_edit_done` 재사용.
- [x] **지도 화면** `screen-map`(치즈/치리토크/리워드) — **b521**. 전체화면·현재위치 title, 잔액(`残高`/`pt`), `チリトーク` 헤더, 출석/광고 카드, 💬 코멘트. 키 `map.*`(8). `coin.balance`/`coin.unit`/`ct.tab.talk`/`rw.attendance`/`sd.write_comment`/`ct.map.pin.hint` 재사용.
- [x] **설정 + 추천(레퍼럴) + 온보딩** — **b522**. 폰트크기(小/標準/大/特大)·`チリ` 단위·푸터 링크 / 추천 코드적용·실패·코드없음·본인·이미적용 토스트·친구가입 푸시·초대링크복사 / 온보딩 버튼·폰트 토스트. 키 `ref.*`(9)+`common.guest`+`settings.fs_*`(4)+`unit.chiri`+`onb.start_free`/`next`+`settings.fontsize_done`.
- [x] **홈/이력** — **b523**. 홈 추천보상 배너, 이력 빈 월 메시지, 리포트 공유 캔버스 제목. 키 `home.ref_reward_*`(3)+`hist.no_records`+`rep.share_title`. (today-label/home-label/hist-month-label·ov-multi·ov-memo는 기존 t()/data-i18n로 이미 완비 확인.)
- [x] **출석/광고시청 페이지 정적 + 출석 렌더** — **b524**. ov-attendance 제목·광고시청 페이지(자동재생/데일리힌트/광고/AdSense/프리미엄/詳細)·완료시트·출석 렌더(요일헤더 등). 키 `att.title/done/bonus_ad_title/dow`+`ad.autoplay_short/daily_hint`, 기존 ad.*/unit.chiri 재사용.
- [x] **광고 시청 완료 화면·토스트** — **b525**. 보상/출석/보너스/추천/댓글한도/프라이빗/치리공개/메뉴사진/월별리포트/리포트펼침/저장 11분기 타이틀·토스트. 키 `adc.*`(18), `+Nチリ獲得`=`adc.earned{n}`.

---

## ⬜ 남은 잔여 그룹 (저빈도/판단 필요 — 주요 화면은 전부 완료)

- **코인 내역 라벨**: `ctAddCoin(n, '📌 手動ピン登録'/'🧾 チリつも共有'/'📅 出席チェック'/'📺 広告視聴' 등, type)` — 여러 호출에 흩어진 일본어 라벨. **치리 내역(coin history) 화면에만** 표시됨. 일괄 처리 권장(키 `coinlog.*` 신설 후 ctAddCoin 호출부 일괄 치환). 저빈도.
- **`renderPriceComparison`(가격 비교 탭)**: 커뮤니티와 별개 기능(지도 패널 compare 탭). 한국어 가능성 — 미조사. 필요 시 별도 확인.
- **업로드 확인 모달 등 엣지**: `ov-upload-confirm`(~4316 `광고 시청 후 업로드 · 보상 +10チリ` 등) 일부 정적 — 미세 잔여. 저빈도.
- **GPT설정** `_authRenderGptConfig`(`✅ OpenAI 키 저장됨…`): 개발/디버그용 추정 — 사용자 노출 여부 확인 후 결정(개발용이면 스킵).
- **가짜 광고 미리보기**(`ov-saveconfirm` 시뮬레이션 장식 `広告` 등): 실제 광고를 흉내낸 chrome → **보류**(실광고로 대체됨).
- **SEO 랜딩/블로그**(971~1047): 정책상 **일본어 고정**(대상 아님).

---

## 메모
- 줄번호 다 이동했음(b521 시점). 검색은 **함수명/요소 id/원문 문자열**로.
- 한 영역 끝낼 때마다 빌드번호 +1, 영역별 커밋, 이 문서 체크박스 갱신.
