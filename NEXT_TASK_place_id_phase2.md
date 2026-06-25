# NEXT TASK — #6 Phase 2: 가게 식별을 place_id 로 전환 (동명 지점 분리)

> 작성: 2026-06-24 · 선행: Phase 1(b556) 배포 완료(place_id 수집·백필).
> 이 작업은 **핵심 맵/가게 식별 체계 리팩터**라 집중 세션 + 충분한 테스트 필요. 한 번에 밀지 말 것.

---

## 0. 배경 (확정된 진단)

- `stores` 는 **`name` 으로 식별**됨 (live DB 에서 `name` UNIQUE — 스키마 파일엔 없지만 `onConflict:'name'` 이 동작하므로 존재).
- 같은 이름의 다른 지점(체인: セブンイレブン/マクドナルド 등) → **한 행으로 합쳐지고 좌표가 덮어써짐**.
- 제대로 된 식별자 `place_id`(Google Places, 지점마다 유일, `stores.place_id TEXT UNIQUE`)는 **Phase 1 부터 수집 시작**했으나 아직 식별 키로 안 씀.

## 1. Phase 2 목표

- 식별 키를 **place_id 우선**으로 전환 → 같은 이름 다른 지점이 **별도 stores 행**으로 분리.
- **`stores.name` 의 UNIQUE 제약 제거가 불가피** (같은 이름 2행 공존하려면 name 이 유니크면 안 됨).

## 2. ⚠️ 핵심 난점 — name UNIQUE 제거의 파급

name 이 더는 유니크가 아니게 되면, 지금 **가게를 이름으로 조회/수정**하는 모든 곳이 **여러 지점 행에 동시에 걸릴 수 있음** → 정보 혼선/업데이트 번짐. 아래를 전부 **id/place_id 기준**으로 바꾸거나 "한 행만" 의미를 명확히 해야 함.

### 2-A. 가게 쓰기(write) — place_id 우선으로 재구성
| 위치 | 현재 | 변경 |
|---|---|---|
| `_persistPinToSupabase` (~16856) | `stores.upsert(..., {onConflict:'name'})` | **geocode 먼저 → place_id 있으면 onConflict place_id, 없으면 폴백** |
| submitChiriPublish 콜백 (~13917~13927) | `update({lat,lng}).eq('name')` + place_id 백필(Phase1) | 위 통합 흐름으로 흡수 |

### 2-B. 가게 읽기/수정 by name — 검토·전환 필요
| 위치 | 용도 | 위험/처리 |
|---|---|---|
| 6200 `select.in('name', names)` | 좌표 배치 조회 | 동명이면 좌표 모호 → id 기반 재검토 |
| 15373 `select.in('name', needFetch)` | 좌표 배치 조회 | 동상 |
| 19338 `select google_maps_url .eq('name')` | 가게 상세 | 한 지점만 — id 기준으로 |
| 20513 `select id .eq('name', _sdName)` | **가게 상세 진입(핵심)** | maybeSingle → 동명이면 첫 행만. id/place_id 로 열도록 |
| 26931 `select * .eq('name', storeName)` | 상세/어드민 | 동상 |
| 27570 `select id .eq('name', _admEditMenuStoreName)` | 어드민 메뉴편집 | id 기준 |
| 28033 `update featured=null .eq('name', _sdName)` | **featured 가격 해제** | ⚠️ 동명 전 지점에 번짐 → id 기준 필수 |
| 28039 `update featured .eq('name')` | featured 가격 설정 | ⚠️ 동상 |

### 2-C. 렌더/그룹핑 키 by name — 분리 보장
| 위치 | 용도 | 처리 |
|---|---|---|
| 6923/6926 | 로드 dedup 키 `name|item` | `store_id` 기준으로 |
| 7001/7041/7052/25358 | 마커 클러스터/그룹 키 = `stores.name` | `stores.id` 우선(있으면) |

> id 로만 다루는 곳(26868/27115/26860/27876/28368/28349)은 **안전 — 변경 불필요**.

## 3. SQL 마이그레이션 (Phase 2 시작 시 Supabase 에서 실행)

```sql
-- (1) name UNIQUE 제거 — 실제 제약/인덱스 이름을 먼저 확인:
--     SELECT conname FROM pg_constraint WHERE conrelid='stores'::regclass AND contype='u';
--     SELECT indexname FROM pg_indexes WHERE tablename='stores';
--   그 이름으로:
-- ALTER TABLE stores DROP CONSTRAINT <stores_name_key 등>;   -- 또는 DROP INDEX <...>;

-- (2) place_id UNIQUE 는 유지 (이미 있음). 없으면:
-- CREATE UNIQUE INDEX IF NOT EXISTS stores_place_id_uniq ON stores(place_id) WHERE place_id IS NOT NULL;

-- (3) place_id 없는 가게의 name-폴백 upsert 를 위해(선택):
--   부분 유니크 (place_id NULL 인 것만 name 유니크) — onConflict 추론은 PostgREST 한계로 어려우니
--   클라에서 "select→insert/update" 수동 폴백 권장.
```

> ⚠️ name UNIQUE 제거 후엔 `onConflict:'name'` upsert 가 깨짐 → **클라에서 name 폴백은 수동(select 후 분기)** 으로.

## 4. 권장 클라 흐름 (geocode-first)

```
publish/manual:
  1) 로컬 핀 즉시 표시(_ctPendingPins) — UX 유지
  2) searchAndPinStore → {lat,lng,place_id}  (실패 시 fallback 좌표 + place_id=null, 6s 타임아웃)
  3) 가게 upsert:
       place_id 있음 → stores.upsert(row, {onConflict:'place_id'}) → store_id
       place_id 없음 → select by name(+근접좌표) → 있으면 그 id, 없으면 insert
  4) 핀 upsert(store_id, user_id, item_name)  ← 이미 b555 에서 적용된 onConflict 유지
```

- **수동 핀(submitManualPin)**: 좌표가 유저가 직접 찍은 위치 → place_id(이름검색) 와 어긋날 수 있음. Phase 2 에서도 **수동 핀은 name/좌표 기준 유지** 검토(또는 reverse-geocode 로 place_id 확인). 무리하게 강제하지 말 것.

## 5. 진행 순서 & 롤백 포인트

1. **클라 먼저 작성**(geocode-first + place_id 우선 + name 수동폴백), 단 **SQL(name unique 제거) 전엔 배포 금지**.
2. 2-B/2-C 의 by-name 지점들을 id/place_id 기준으로 **모두** 수정.
3. 스테이징 느낌으로: SQL 실행(name unique drop) → 클라 배포 → **실제 영수증 공개로 핀 생성 테스트**(동명 체인 2곳을 다른 위치에서 등록 → 2행 분리 확인).
4. 롤백: 문제 시 클라 즉시 직전 빌드로 되돌림. name unique 는 **중복 행이 안 생겼다면** 재생성 가능하지만, 동명 중복이 이미 생기면 수동 병합 필요 → **테스트 시 소량으로**.

## 6. 테스트 체크리스트

- [ ] 동명 체인 2곳(다른 위치) 등록 → stores 2행(서로 다른 place_id)로 분리
- [ ] 가게 상세 진입이 올바른 지점 1곳만 로드
- [ ] featured 가격 설정/해제가 다른 지점에 안 번짐
- [ ] 같은 가게 재등록 → 가격만 갱신(핀 중복 X, b555 유지)
- [ ] place_id 못 찾는 가게(희귀) → 폴백으로 정상 저장
- [ ] 수동 핀 위치가 유저가 찍은 대로 유지

## 7. 영향 파일
- `public/index.html` (단일 파일): 위 모든 지점
- Supabase: stores name UNIQUE 제거 SQL
- 배포: build 2곳(`__APP_BUILD__` + `sw.js CACHE_NAME`) 동시 bump
