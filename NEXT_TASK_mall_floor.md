# 🔜 다음 작업 (먼저 할 것) — 몰/빌딩 "층(階)" 구분

> **다른 PC에서 이어서 작업 시작할 때 이 파일을 먼저 읽고 진행할 것.**
> 작성: 2026-06-18 (build 538 시점) · 상태: **미착수(설계만 확정)**

---

## 0. 한 줄 요약
쇼핑몰처럼 **같은 좌표(lat/lng)에 여러 가게가 층층이** 있는 경우를 위해, 가게에 **`floor`(층) + `building`(빌딩명)** 정보를 추가해 상세/지도에서 "○○モール 3F"로 구분 표시한다.

## 1. 배경 / 왜 이 방식인가 (결정 기록)
- 사용자 질문: "쇼핑몰은 구글맵에서 층별로 볼 수 있는데 우리는 불가능한가?"
- **Google 인도어맵(층 평면도+층 선택기)은 우리가 제공 불가**:
  - Google이 직접 측량·보유한 건물만, 고배율 확대 시에만 자동 표시. 우리가 켜거나 만들 수 없음.
  - 우리 데이터 모델 = **가게 1개 = 좌표 1점** → 몰 안 3F든 B1이든 전부 같은 점으로 찍힘. 인도어맵 띄워도 "우리 가게가 그 층 어디"는 표현 불가.
- **채택안 = 우리가 제어 가능한 메타데이터**: `floor`/`building` 텍스트 필드. 좌표가 같아도 층/빌딩으로 구분 + 마커 겹침 해소. Google 인도어맵 흉내보다 실효적.

## 2. 현재 코드 사실 (착수 전 확인됨)
- **`stores` 테이블** (`chiritsmo_schema.sql:56`): `id, place_id, name, address, lat, lng, category, receipt_count, avg_price, created_at` + (별도 마이그레이션으로 추가된) `google_maps_url`. → **`floor`/`building` 컬럼 없음.**
- **어드민 가게 편집 UI** (`public/index.html`):
  - 입력 필드: `adm-store-name`(3463), `adm-store-gmap`(3469), `adm-store-lat`(3493), `adm-store-lng`(3494). 저장 버튼 `admSaveStore()` (3497).
  - 로드(편집 진입): `~27668` (`adm-store-name'.value = s.name` 등).
  - 저장 함수: **`async function admSaveStore()` (28147)**.
- **유저 가게 상세**: `_sdName` 기반 렌더(11269~). 지도 핀: `price_pins` + `stores(...)` join (6772), 같은좌표 클러스터 로직 (6944~6957 부근 dLat/dLng 비교).

## 3. 구현 단계

### SQL (Supabase SQL Editor — 사용자가 실행)
```sql
-- 몰/빌딩 층 구분 (store_floor.sql)
alter table public.stores add column if not exists floor    text;  -- 예: 'B1','1F','3F','RF'
alter table public.stores add column if not exists building text;  -- 예: '晴海アイランド トリトンスクエア'
```
> RLS 정책 변경 불필요(기존 stores 정책 그대로). 어드민만 쓰기 가능한 현 구조 유지.

### Phase 1 — 어드민 입력 + 상세 표시 (필수)
1. **어드민 입력 필드 추가** (`public/index.html` ~3494 lat/lng 아래):
   - `adm-store-building`(텍스트, placeholder "빌딩/몰 이름 (선택)"), `adm-store-floor`(텍스트, placeholder "층 (예: 3F, B1)").
2. **로드** (~27668): `adm-store-building'.value = s.building||''`, `adm-store-floor'.value = s.floor||''`.
3. **저장** (`admSaveStore()` 28147): upsert payload에 `building`, `floor` 추가.
4. **유저 가게 상세** 헤더(가게명 옆/아래): `building` 있으면 "🏢 {building} {floor}" 표시. 좌표만 같던 가게가 구분됨.
5. **i18n** (4언어): `sd.floor_label`(층), `sd.building_label`(빌딩) 등 표시용 — admin 입력 라벨은 한국어 고정(어드민 규칙).

### Phase 2 — 지도 같은좌표 묶기 (선택, Phase 1 이후)
- 치리맵 클러스터에서 **동일 좌표(±오차) 핀들을 `building` 단위로 그룹핑** → 펼치면 층순 정렬 리스트.
- 핀 상세(그룹) 렌더에서 각 가게에 `floor` 배지.
- 관련 로직: 6944~6957 같은좌표 비교부, 핀 그룹 렌더.

## 4. 작업 규칙 리마인더 (HANDOFF.md 헤더 참조)
- 변경은 **`main` 직접 커밋·push**. 빌드번호 2곳(`index.html`의 `window.__APP_BUILD__`, `sw.js`의 `CACHE_NAME='...-bNNN'`) 같이 올리기.
- 커밋 전 문법검사:
  ```bash
  node -e "const fs=require('fs');const h=fs.readFileSync('public/index.html','utf8');const m=h.match(/<script>([\s\S]*?)<\/script>/g)||[];let bad=0;m.forEach((s,i)=>{const b=s.replace(/^<script>/,'').replace(/<\/script>$/,'');try{new Function(b)}catch(e){bad++;console.log('SCRIPT#'+i,e.message.split('\n')[0])}});console.log(bad?'ERR '+bad:'OK '+m.length)"
  ```
- 새 UI 텍스트는 **4개국어 i18n**(어드민 라벨 제외 — 한국어 고정).

## 5. 사용자에게 물어볼 것 (착수 시)
- `floor`/`building`을 **유저 영수증 등록 흐름에서도 입력**받게 할지, 아니면 **어드민·가게수정요청에서만** 관리할지. (기본 추천: 우선 어드민/가게수정요청만 → Phase 1 가볍게)
- Phase 2(지도 묶기)까지 갈지, Phase 1(표시)만으로 충분한지.
