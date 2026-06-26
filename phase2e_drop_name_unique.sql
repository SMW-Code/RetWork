-- ════════════════════════════════════════════════════════════════════════════
-- #6 Phase 2e (비가역) — stores.name UNIQUE 제거 → 동명 다른지점 분리 허용
--
-- ⚠️ 비가역: 실행 후 같은 이름 가게가 여러 행으로 갈릴 수 있고, 한 번 갈리면
--    되돌리기 어렵다. 클라이언트(b570)는 이미 store_id 기반으로 전부 준비됨.
--    place_id 가 새 식별자(이미 UNIQUE). name 은 표시용으로 남김(컬럼 유지).
--
-- 실행 전 제 안내(앱 동작 확인)까지 끝났는지 확인하고 RUN.
-- ════════════════════════════════════════════════════════════════════════════

-- ── Part 0. stores 백업 스냅샷 (복원용) + RLS 차단 ──
CREATE TABLE IF NOT EXISTS _bak2e_stores AS SELECT * FROM stores;
ALTER TABLE _bak2e_stores ENABLE ROW LEVEL SECURITY;   -- 정책없음=API 차단(관리자/SQL은 접근)

-- ── Part 1. 최종 backfill (그동안 생긴 store_id NULL 커뮤니티 행 보강) ──
BEGIN;
UPDATE store_comments c         SET store_id = s.id FROM stores s WHERE c.store_id IS NULL AND c.store_name = s.name;
UPDATE store_menu_cards c        SET store_id = s.id FROM stores s WHERE c.store_id IS NULL AND c.store_name = s.name;
UPDATE store_community_photos c  SET store_id = s.id FROM stores s WHERE c.store_id IS NULL AND c.store_name = s.name;
UPDATE store_photos c            SET store_id = s.id FROM stores s WHERE c.store_id IS NULL AND c.store_name = s.name;
UPDATE pin_ratings c             SET store_id = s.id FROM stores s WHERE c.store_id IS NULL AND c.store_name = s.name;
COMMIT;

-- ── Part 2. place_id UNIQUE 보장 (없으면 생성; 이미 있으면 무시) ──
--   place_id NULL 다수는 허용해야 하므로 부분 유니크.
CREATE UNIQUE INDEX IF NOT EXISTS stores_place_id_uniq
  ON stores(place_id) WHERE place_id IS NOT NULL;

-- ── Part 3. name UNIQUE 제약/인덱스 제거 (동적 — 실제 이름 자동 탐지) ──
DO $$
DECLARE r record;
BEGIN
  -- 3a) UNIQUE 제약 중 (name) 단독인 것 DROP
  FOR r IN
    SELECT conname FROM pg_constraint
    WHERE conrelid = 'public.stores'::regclass AND contype = 'u'
      AND pg_get_constraintdef(oid) ILIKE '%(name)%'
  LOOP
    EXECUTE 'ALTER TABLE public.stores DROP CONSTRAINT ' || quote_ident(r.conname);
    RAISE NOTICE 'dropped constraint %', r.conname;
  END LOOP;
  -- 3b) 제약 없이 만들어진 UNIQUE INDEX 중 (name) 인 것 DROP
  FOR r IN
    SELECT indexname FROM pg_indexes
    WHERE schemaname = 'public' AND tablename = 'stores'
      AND indexdef ILIKE '%UNIQUE%' AND indexdef ILIKE '%(name)%'
      AND indexname NOT IN (SELECT conname FROM pg_constraint WHERE conrelid='public.stores'::regclass)
  LOOP
    EXECUTE 'DROP INDEX IF EXISTS public.' || quote_ident(r.indexname);
    RAISE NOTICE 'dropped index %', r.indexname;
  END LOOP;
END $$;

-- ── Part 4. 검증 ──
-- (a) name UNIQUE 가 없어야 함 (아래 둘 다 0행이면 제거 성공)
SELECT conname AS remaining_unique_constraint_on_name FROM pg_constraint
  WHERE conrelid='public.stores'::regclass AND contype='u'
    AND pg_get_constraintdef(oid) ILIKE '%(name)%';
SELECT indexname AS remaining_unique_index_on_name FROM pg_indexes
  WHERE schemaname='public' AND tablename='stores'
    AND indexdef ILIKE '%UNIQUE%' AND indexdef ILIKE '%(name)%';
-- (b) place_id UNIQUE 존재 확인
SELECT indexname FROM pg_indexes WHERE tablename='stores' AND indexname='stores_place_id_uniq';

-- ════════════════════════════════════════════════════════════════════════════
-- 실행 후: 같은 이름 다른지점을 다른 위치에서 공개 → stores 2행(다른 place_id) 분리,
--   커뮤니티 데이터도 store_id 따라 분리. (기존 합쳐진 데이터는 소급 분리 불가)
-- 롤백: name UNIQUE 재생성은 동명 중복행이 없을 때만 가능. _bak2e_stores 로 참조 복원.
-- ════════════════════════════════════════════════════════════════════════════
