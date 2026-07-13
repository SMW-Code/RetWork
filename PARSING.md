# PARSING.md — RetWork 영수증 파싱 설계서

> **목적:** 영수증 OCR→구조화 파싱 로직·프롬프트·해결한 문제를 한곳에 정리.
> 프롬프트를 업데이트하거나 파싱 정확도 문제가 생겼을 때 **이 문서를 기준으로** 디버깅·개선한다.
> ⚠️ 파싱 로직을 수정하면 **이 문서와 `public/table-proto.html`(좌표파서 실험장)을 함께 갱신**할 것.
> 최종 갱신: build 590 시점.

---

## 0. 한눈에 보는 파이프라인

```
사진(카메라/갤러리)
  │
  ▼ ① 전처리  preprocessReceiptImage()           [public/index.html ~11374]
  │    · EXIF 방향 보정, 리사이즈(MAX 4000 / MIN 1200), 대비 보정, JPEG(q0.92) → base64
  │
  ▼ ② OCR  /api/vision (Google Vision TEXT_DETECTION)   [app/api/vision/route.ts]
  │    · 반환: fullTextAnnotation.text(전체 텍스트) + textAnnotations[](단어별 좌표 boundingPoly)
  │
  ▼ ③ 1차 파서: 좌표 기반 표복원  parseReceiptByCoords()  [~12755]
  │    · 단어 좌표로 '행/열'을 복원 → 품목·수량·가격 매칭
  │    · 검증(품목합 == 小計/合計, 세율 역산 포함) 통과 → _valid=true → **즉시 채택, GPT 생략**(비용 0)
  │    · 검증 실패 → ④로 폴백
  │
  ▼ ④ 폴백: 하이브리드 GPT  showOcrDebugHybrid()         [~12150]
  │    · OCR 텍스트(행번호 부여) + 원본 이미지(base64) 를 함께 GPT에 전달
  │    · 모델 2단: gpt-4o-mini(저렴) → 검증 실패 시 gpt-4o(정확) 폴백
  │
  ▼ ⑤ 후처리
       · "F " 접두사 제거, 숫자 정규화
       · 날짜 元号→西暦 변환(클라), 주차 분(分) 파싱, 카테고리 자동분류
       · 식료품이면 _contributeProductPrices() 로 커뮤니티 가격풀(product_prices) 기여
```

**핵심 설계 철학**
- **좌표 파서 우선, GPT는 폴백.** 좌표 파서가 검증을 통과하면 GPT를 호출하지 않아 **비용 0 + 빠름**. 일본 영수증은 표 구조가 일정해서 상당수가 좌표 파서로 해결됨.
- **합계(合計) 정확도 최우선.** 개별 품목 순서보다 `sum(items) ≈ 合計`가 맞는지가 채택/폴백의 기준.
- **하이브리드(텍스트+이미지).** 텍스트만 주면 70~80%, 이미지까지 같이 주면 88~93% (실측 기준 주석).

---

## 1. 단계별 상세

### ① 전처리 `preprocessReceiptImage(file, opts)` (~11374)
- `createImageBitmap(file, {imageOrientation:'from-image'})` 로 **EXIF 회전 자동 보정**.
- 리사이즈: `MAX=4000`, `MIN=1200`, `quality=0.92`.
  - ⚠️ MAX를 2400으로 낮췄더니 세로 긴 영수증의 가로 해상도가 ~983px로 떨어져 글자가 뭉개짐 → 좌표 파서가 컬럼 분리 실패. 그래서 **4000 유지**(본문 크기는 가드로 제한).
- 실패 시 원본 dataURL 폴백.
- 산출물: `{ dataUrl(미리보기), base64, width, height }`.

### ② OCR `/api/vision` (`app/api/vision/route.ts`)
- 런타임 `nodejs`, `force-dynamic`.
- 키 후보 여러 개 순차 시도: `GOOGLE_VISION_API_KEY` / `VISION_KEY` / `VISION_API_KEY` / `GOOGLE_VISION_KEY` / `GCP_VISION_KEY` (어느 이름으로 등록돼 있어도 동작).
- Google Vision `images:annotate`, `features:[{type:'TEXT_DETECTION'}]`.
- 반환: `responses[0].fullTextAnnotation.text` (줄바꿈 포함 전체 텍스트) + `responses[0].textAnnotations[]` (단어별 `boundingPoly.vertices` 좌표). **textAnnotations[0] 은 전체 묶음이라 `.slice(1)` 로 단어들만 사용.**
- ⚠️ Vercel Attack Challenge Mode 가 HTML(challenge)을 반환하면 `x-vercel-mitigated:challenge` 또는 `content-type: text/html` → `__VERCEL_CHALLENGE__` 에러로 처리해 사용자 안내.

### ③ 1차 파서: 좌표 기반 `parseReceiptByCoords(annotations, rawText)` (~12755)
호출부: `callGoogleVisionAPI` 의 `.then` 안 (~11541).

알고리즘 요약:
1. `extractWords()` — 각 단어의 중심좌표(cx,cy)·상하좌우·높이(h) 계산. 줄바꿈 포함 토큰 제외.
2. 좌우 경계 L/R로 폭 W 산출 → `nameColX = L+0.50W`, `priceColX = L+0.60W` (품목명 영역 / 가격 영역 분리 기준선).
3. `medH`(중앙 글자높이)로 행 밴드 `band = max(16, medH*0.7)` 결정 → 같은 cy 밴드 안 단어들을 한 줄로 묶음.
4. **가격 토큰** `isPriceTok`: 돈 모양(`isMoneyShape`) + `cx>priceColX` + 값 10~1e7(등록번호 등 비현실적 큰 수 제외).
5. **상단/하단 경계**: 앵커(人数/伝票/テーブル/領収) 아래부터, 첫 `小計/税抜/合計` 위까지가 품목 영역.
6. **품목명 행** `nameLines`: priceColX 왼쪽 단어를 cy로 묶고 `cleanName()`(장식기호·선두숫자 제거). `@`/`個`/`(` 포함 행은 `unitish`(수량단가 행)로 표시 → 품목명에서 제외.
7. **단가(@단가) 토큰** `units`: `@¥398` 또는 `@` 우측 숫자 수집.
8. **가격↔품목 매칭**: 같은 행에 숫자가 여럿이면(単価/点数/金額) **맨 오른쪽=라인합계(金額)만** 가격으로. 각 가격은 cy가 가장 가까운(아래쪽 ~50px) 미사용 품목명 행에 매칭. `META_NAME` 정규식에 걸리는 이름(店/登録/番号/税/合計 등)은 제외.
9. **수량 추론**: 이름과 가격 사이의 1~2자리 숫자, 또는 `price % unit === 0 && 1<=price/unit<=99` 이면 그 몫을 qty 로.
10. `小計`/`合計` 토큰 추출 → **검증**(아래 §4).
11. store(rawText 상단 줄에서 추출), date(`YYYY年MM月DD` 정규식), `autoClassify()` 카테고리.

**다른 텍스트 전용 파서** `parseReceiptText(rawText)` (~12905) 도 존재(좌표 없는 경우 대비 멀티패턴 A/B/C). 현재 메인 흐름은 좌표→GPT.

### ④ 폴백: 하이브리드 GPT (~12150)
- OCR 텍스트에 **행 번호를 붙여**(`numberedText`) 프롬프트에 포함 + 원본 이미지(base64, `detail:'high'`)를 함께 전달.
- 시스템 프롬프트(아래 §2) + 유저 메시지(텍스트+이미지).
- 모델 2단 전략(§3).

### ⑤ 후처리
- `name.replace(/^F\s+/, '')` — 식품 표시 "F " 제거.
- 날짜: 프롬프트는 **원본 표기 그대로** 반환(元号 변환 금지) → **클라이언트가 元号→西暦 변환**(令和/平成 + 2자리 연도 등 처리).
- 주차 품목: `_parseParkingMins()` 로 주차시간(분) 파싱 → items[].mins 보존(¥/시간 비교용).
- 주유 품목: 수량이 리터수 → 월별 리포트에서 `_FUEL_RE` 로 감지해 "NL·리터당 ¥" 표기(b590).
- 식료품(슈퍼/편의점)이면 `_contributeProductPrices()` 가 정규화 product_id + 가게 + 단가 + 좌표를 공개 `product_prices` 에 upsert (커뮤니티 가격 비교/검색의 원천).

---

## 2. GPT 시스템 프롬프트 (단일 영수증) — **전문**

> 위치: `public/index.html` 의 `var systemPrompt` (~12206). 모델: 기본 `gpt-4o-mini`, 폴백 `gpt-4o`.
> `temperature:0`, `max_tokens:2500`, `response_format` 는 호출에 따라 `json_object`.
> **이 블록을 수정하면 반드시 4개 항목(출력포맷/특수룰/예시/일반룰) 정합성을 확인**하고, 검증(§4)으로 회귀 테스트할 것.

```text
あなたは日本のレシート・領収書・請求書・インボイスを解析するAIです。
以下のルールに厳密に従い、JSONのみを出力してください。
説明・前置き・マークダウン・コードブロックは一切不要です。

## 出力フォーマット
{"store":"店名","date":"YYYY-MM-DD","address":"店舗住所 or null","total":0,"pay":"credit|debit|ic|qr|cash or null","items":[{"name":"商品名","qty":1,"price":0,"discount":0}]}

## ★支払い方法の判定（pay フィールド）★
- "クレジット"/"VISA"/"Master"/"JCB"/"AMEX"/"一括"/"分割" → "credit"
- "デビット"/"J-Debit" → "debit"
- "交通系"/"Suica"/"PASMO"/"iD"/"QUICPay"/"電子マネー"/"WAON"/"nanaco"/"Edy" → "ic"
- "PayPay"/"楽天ペイ"/"d払い"/"au PAY"/"メルペイ"/"LINE Pay"/"QR"/"コード決済" → "qr"
- "現金"/"現計"/"お預り"/"釣"/"CASH" → "cash"
- 判別不能 → null

## ★領収証（手書き）専用ルール★   (領収証/収入印紙/様 + 품목 없음 / "¥"만 있는 행 + 후행 "2790-" 패턴)
R-1. 금액 특수표기: "¥2790-" → 2790 / "¥"행 + 후행 숫자행 = 금액 / 숫자행 여럿이면 최대값=합계
R-2. 내역 공백 → items=[{"name":"お食事代","qty":1,"price":total}]
R-3. 하단 店名도 추출(有限会社/株式会社 등 법인격 포함, TEL/住所/登録番号 제외)
R-4. 노이즈 제거(키보드키/様/収入印紙/T登録番号/URL/OCR단편)

## ★コストコ専用ルール（最優先）★
C-1. 품목=2행 세트. 행②의 마지막 숫자(小計)가 실제 금액. 코드번호(5~7자리)는 가격 아님
C-2. "1●/2●/3●" = qty. price=小計
C-3. CPN 할인행 → 직전 품목 discount 음수로, items 추가 안 함
C-4. 같은 품목 여러 번이어도 절대 중복삭제 금지
C-5. 제외행: BOTTOM OF BASKET / 会員 / 売上 / **** 合計 / クレジット* / 御買上げ点数 / 消費税 …
C-6. G-MBR(P) RENEWAL = 회비, items 포함

## ★일본 슈퍼/편의점 행 구조 (가장 중요!)★
S-1. 3패턴: A) 품목/¥가격  B) 품목/2コX単398/¥796(소계)  C) 품목에 ×N 인라인/¥가격
S-2. 품목명 바로 다음(또는 수량단가 행 건너뛴 다음) ¥금액이 그 가격. **한 줄씩 밀려서 매칭 금지**
S-3. 노이즈행 items 금지: 점포/주소/전화/사업자번호/스캐너/회원안내/小計·合計·税·결제/푸터/단독"¥"
S-4. 선두 "F " 제거(식품 8% 표시)
S-5. 합계: "合計"/"合計/N点" 다음 ¥숫자. **小計는 합계 아님.** items 합으로 total 채우지 말 것
S-6. 검증: sum(items.price) 가 total과 ±5% 이내

## ★음식점·식당(라면/정식/이자카야/카페/소바)★
RES-1. 보통 1행=[메뉴][수량][금액]. 들여쓰기 옵션(味玉/トッピング/大盛/セット)도 각각 별도 item. 같은 메뉴 중복행도 합치지 말 것
RES-2. ★금액은 그 행 숫자 그대로 price★ (수량 2 이상이어도 곱하지 마라 — 이미 합산 금액)
   예: "白ごはん 2 ¥400" → price 400 (800 아님)
RES-3. 모든 품목행 추출, sum==小計/合計. 모자라면 누락행(특히 들여쓰기 옵션) 추가
RES-4. 小計/合計/消費税/お預り/お釣り/クレジット/登録番号 행은 품목 아님

## 一般パースルール
1. 실제 구매 품목만(소계/합계/세/지불/할인/헤더/푸터 제외)
2. 수량: (NコX単M)/@MxN/N● → qty:N, unit_price:M
3. 분류기호 제거: 3類/◆指/※/▽/★
4. 가격: ¥ \ * # 円 JP¥ 末尾- 모두 엔화. 점(.)은 천단위(¥21.911=21911)
5. 할인줄 discount 음수, 독립할인 discount_total
6. 합계는 마지막 合計. 現金/クレジット行은 합계 아님
7. ★날짜: 영수증 원본 표기 그대로 반환. GPT가 元号→西暦 변환 금지(클라가 처리).★
   허용: 令和6年5月3日 / 平成26年6月4日 / 26年6月4日 / 2026年6月4日 / 26.06.04 / 2026/6/4 …
   절대 ISO("2014-06-04")로 변환해 보내지 마라
8. 주유소: 연료종류 품목명 / 주차장: "駐車料金"
9. 손글씨·금액만 → items=[{"name":"お食事代","qty":1,"price":total}]

JSONのみ出力。説明不要。
```

(위는 가독성을 위해 일부 축약. **정본은 코드의 `systemPrompt` 변수**이며, 코드가 항상 우선이다.)

유저 메시지(`userContent`):
```js
[ {type:'text', text:'以下のレシートを解析してください。\n\n【OCRテキスト（行番号付き）】\n' + numberedText},
  {type:'image_url', image_url:{ url:'data:image/jpeg;base64,'+base64Image, detail:'high' }} ]
```

---

## 3. GPT 모델 전략 (mini → 4o 폴백) + 검증

`_callGptModel(modelName)` + `_validateResult()` (~12416):

1. **1차 `gpt-4o-mini`** 호출(저렴, ~¥0.07).
2. 응답에서 ```json 코드펜스 제거 → `JSON.parse`.
3. `_validateResult`:
   - items 비어있으면 실패.
   - `sum = Σ items.price`, `total`.
   - **sum > total**: 오버카운트 → `(sum-total)/total < 5%` 여야 통과.
   - **sum < total**: 소비세 포함 가능성 → `(total-sum)/total < 12%` 까지 허용(세 10% + 여유).
4. 통과 → 채택. **실패 → `gpt-4o` 재시도**(정확, ~¥1.24)하고 그 결과 채택.

> 왜 이 비대칭 허용폭? 일본 영수증은 **품목가=세전(税抜), 합계=세포함(税込)** 이라 sum<total 8~10% 차이는 정상. 반대로 sum>total 은 행 밀림/중복의 신호라 5%로 엄격.

---

## 4. 검증 규칙 (채택/폴백 기준)

### 좌표 파서 `_valid` (~12874)
```
valid = items.length>0 && (
   (小計>0 && itemSum===小計)                      // 세전 소계와 정확히 일치
|| (合計>0 && itemSum===合計)                      // 내세(税込)면 합계와 일치
|| (合計>0 && (round(itemSum*1.10)===合計 || round(itemSum*1.08)===合計)) // 외세: 세율 역산 일치
)
```
→ **정확히 일치(또는 세율 역산 일치)할 때만** 좌표 파서 채택. 조금이라도 어긋나면 GPT로.

### GPT 결과 `_validateResult` → §3 (±5% / ±12%)

이 "합계 검증" 이 **품질의 핵심 안전망**. 행이 밀리거나 누락되면 합이 안 맞아 자동으로 더 좋은 경로로 폴백됨.

---

## 5. 분할 촬영(긴 영수증 여러 장) 프롬프트 (~11051)
- 여러 장을 한 번에 찍어 OCR 텍스트를 **합본**(행번호 부여) → `gpt-4o`(정확도 우선), `max_tokens:3000`, `temperature:0`, user 메시지 1개(텍스트만, 이미지 없음).
- 출력 포맷 동일(JSON). 합계는 **마지막 장의 合計**.
- 단일 영수증 프롬프트와 별개이므로 **둘 다 같이 유지보수**할 것.

---

## 6. 해결한 문제 ↔ 대응 규칙 (히스토리)

각 프롬프트 룰/코드는 실제로 겪은 오파싱을 막으려고 들어간 것:

| 문제 | 증상 | 해결 |
|---|---|---|
| **행 밀림** | 품목명과 다음 줄 가격이 한 칸씩 어긋나 전부 틀림 | S-2 "한 줄씩 밀려 매칭 금지" + 좌표 파서의 cy 근접 매칭 + 합계검증 폴백 |
| **小計를 合計로 오인** | 세전 소계를 총액으로 잡아 금액 과소 | S-5 "小計는 합계 아님", 합계는 "合計/N点" 라벨에서 |
| **세전/세후 차이** | sum(품목) ≠ total 이라 검증 실패 남발 | 외세 세율(1.08/1.10) 역산 허용 + GPT는 sum<total 12%까지 허용 |
| **수량×단가 행을 품목으로** | "2コX単398" 이 별도 품목으로 추가됨 | S-1/S-2, 좌표 파서 `unitish` 행 제외 |
| **음식점 금액 중복곱** | "白ごはん 2 ¥400" 을 800으로 | RES-2 "금액 그대로, qty로 곱하지 마라" |
| **코스트코 코드번호=가격** | 1768085 같은 상품코드를 가격으로 | C-1 "코드(5~7자리)는 가격 아님", 좌표 파서 값 상한 1e7 |
| **손글씨 영수증** | 품목 없고 ¥금액·末尾"-"만 | R-1~R-4 + items=[お食事代] 폴백 |
| **등록번호/전화 오인식** | T번호·전화번호를 금액/품목으로 | META_NAME 정규식 제외 + moneyTok 값 범위 |
| **元号 날짜** | GPT가 令和→西暦 잘못 변환 | 룰7 "원본 그대로 반환", 변환은 클라가 |
| **EXIF 회전/저해상도** | 글자 뭉개져 컬럼 분리 실패 | 전처리 EXIF 보정 + MAX 4000 유지 |
| **비용/속도** | 매번 GPT 호출 | 좌표 파서 우선 채택(검증 통과 시 GPT 0회) + mini→4o 2단 |
| **주차요금 비교 왜곡** | ¥300 vs ¥2,800(시간 다름) | 주차시간(분) 파싱 → ¥/시간 비교(items.mins) |
| **주유 "44回"** | 리터수를 구매 횟수로 표기 | `_FUEL_RE` 감지 → "44L·리터당 ¥164"(b590) |
| **쿠폰 「値引後」를 품목가로** (b609~611) | 마츠키요 등 per-item 쿠폰: サロンパス를 원가 3,102 대신 「(クーポン値引後 ¥2,842)」로 인식 → 할인 733(정답 993), 총액은 맞음 | **S-7 신설**: 品目가=품목명 직후 원가(정가), 「値引後/割引後/카ッコ금액」은 절대 가격 아님, 割引·クーポン·マイナス행은 items 제외, 할인 시 sum>total 정상(±5% 미적용). 앱: `_appendDiscountItem`이 total−품목합을 「쿠폰·할인」 마이너스 품목으로 자동추가 → 小計=合計. 음수 품목은 자주산품목·가격공유·물가비교에서 price>0 필터로 자동 제외 |
| **Vercel challenge** | OCR 응답이 HTML | `x-vercel-mitigated` 감지 → 안내 |

---

## 7. 어디를 고치면 되나 (파일·함수 맵)

| 대상 | 위치 |
|---|---|
| 전처리 | `public/index.html` `preprocessReceiptImage()` ~11374 |
| Vision OCR 라우트 | `app/api/vision/route.ts` |
| OCR 호출·오케스트레이션(좌표→GPT) | `callGoogleVisionAPI()` ~11500 |
| **좌표 파서** | `parseReceiptByCoords()` ~12755 + 실험장 `public/table-proto.html` |
| 텍스트 전용 파서 | `parseReceiptText()` ~12905 |
| **GPT 시스템 프롬프트(단일)** | `var systemPrompt` ~12206 |
| GPT 모델 전략·검증 | `_callGptModel` / `_validateResult` ~12416 |
| 분할 촬영 프롬프트 | ~11051 (gpt-4o) |
| GPT 프록시 라우트 | `app/api/gpt/route.ts` (단순 패스스루) |
| 결과 표시·편집 | `showOcrResult()` / `showOcrDebugHybrid()` |
| 상품 정규화 | `_matchOrCreateProduct()` ~12060 (products_master/aliases) |
| 커뮤니티 가격 기여 | `_contributeProductPrices()` ~13443 |
| 주차 분 파싱 | `_parseParkingMins()` / 주유 감지 `_FUEL_RE` |

---

## 8. 환경변수 (서버 = Vercel `ret-work` 프로젝트)
- `OPENAI_API_KEY` — `/api/gpt`
- `GOOGLE_VISION_API_KEY`(또는 후보 5종 중 하나) — `/api/vision`
- ⚠️ env 입력은 **대시보드**로(CLI는 값 잘림 사고 이력). 실서비스는 `ret-work` 프로젝트(자세히는 HANDOFF 헤더).

## 9. 유지보수 체크리스트 (프롬프트/파서 수정 시)
1. `systemPrompt`(단일) **그리고** 분할촬영 프롬프트 정합성 확인.
2. 좌표 파서 수정 시 `table-proto.html` + **이 문서** 동기화.
3. 실제 영수증 몇 종(슈퍼/편의점/음식점/코스트코/손글씨/주유/주차)으로 회귀 — `sum(items)≈合計` 검증 통과 확인.
4. `index.html` 빌드번호 2곳(`__APP_BUILD__`, `sw.js CACHE_NAME`) + 커밋 전 문법검사(HANDOFF 참고).
5. i18n 영향 없음(파싱은 내부 로직) — 단 사용자 대면 라벨 추가 시 4개국어.

## 10. 알려진 한계 / 개선 후보
- 좌표 파서는 **세로 정렬이 깨진(기울어진/구겨진)** 영수증에 약함 → 그 경우 GPT 폴백.
- `priceColX = L+0.60W` 등 **고정 비율** → 폭이 비정상인 레이아웃에서 오차 가능(튜닝 여지).
- 상품 정규화(product_id)는 정규화명 기준이라 **다른 브랜드/사이즈 과병합** 가능.
- 다국어 OCR: 일본어 최적화. (상품 검색도 canonical 일본어 기준)
- gpt-4o-mini 정확도가 낮은 특정 레이아웃 — 폴백 비율 모니터링 후 프롬프트 보강.
- 개선 아이디어: 영수증 종류 분류 후 종류별 프롬프트 분기, dewarp(원근보정) 전처리(`scan-proto.html` 셸브), few-shot 예시 추가.
