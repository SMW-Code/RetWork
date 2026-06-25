-- ════════════════════════════════════════════════════════════════════════════
-- #6 Phase 2c — 커뮤니티 데이터 store_id backfill (store_name → stores.id)
--
-- 현재 stores.name 이 아직 UNIQUE → store_name 매칭이 1:1 명확(모호함은 2e 이후).
-- store_id 가 NULL 인 행만 채움(2b dual-write 이후 생긴 건 이미 채워져 있음).
--
-- 가역성: store_id 만 채움(store_name·다른 컬럼 불변). 되돌리려면 SET store_id=NULL.
-- 그래도 안전을 위해 Part 0 에서 in-DB 스냅샷 백업 생성.
--
-- Supabase SQL Editor 에 붙여넣고 RUN. (재실행 안전)
-- ════════════════════════════════════════════════════════════════════════════

-- ── Part 0. 백업 스냅샷 (문제 시 복원용 — 나중에 DROP 가능) ──
CREATE TABLE IF NOT EXISTS _bak2c_store_comments         AS SELECT * FROM store_comments;
CREATE TABLE IF NOT EXISTS _bak2c_store_menu_cards        AS SELECT * FROM store_menu_cards;
CREATE TABLE IF NOT EXISTS _bak2c_store_community_photos  AS SELECT * FROM store_community_photos;
CREATE TABLE IF NOT EXISTS _bak2c_store_photos            AS SELECT * FROM store_photos;
CREATE TABLE IF NOT EXISTS _bak2c_pin_ratings             AS SELECT * FROM pin_ratings;

-- 백업 테이블 RLS 켜기(정책 없음 = API 접근 차단, 관리자/SQL 은 그대로). 유저 데이터 노출 방지.
ALTER TABLE _bak2c_store_comments         ENABLE ROW LEVEL SECURITY;
ALTER TABLE _bak2c_store_menu_cards       ENABLE ROW LEVEL SECURITY;
ALTER TABLE _bak2c_store_community_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE _bak2c_store_photos           ENABLE ROW LEVEL SECURITY;
ALTER TABLE _bak2c_pin_ratings            ENABLE ROW LEVEL SECURITY;

-- ── Part 1. backfill (NULL 인 것만, name 매칭) ──
BEGIN;

UPDATE store_comments c
  SET store_id = s.id FROM stores s
  WHERE c.store_id IS NULL AND c.store_name = s.name;

UPDATE store_menu_cards c
  SET store_id = s.id FROM stores s
  WHERE c.store_id IS NULL AND c.store_name = s.name;

UPDATE store_community_photos c
  SET store_id = s.id FROM stores s
  WHERE c.store_id IS NULL AND c.store_name = s.name;

UPDATE store_photos c
  SET store_id = s.id FROM stores s
  WHERE c.store_id IS NULL AND c.store_name = s.name;

UPDATE pin_ratings c
  SET store_id = s.id FROM stores s
  WHERE c.store_id IS NULL AND c.store_name = s.name;

COMMIT;

-- ── Part 2. 검증 ──
-- (a) 아직 store_id 가 NULL 인데 매칭되는 stores 가 있는 행 = 0 이어야 함
SELECT 'store_comments' AS tbl, COUNT(*) AS unmatched FROM store_comments c
  WHERE c.store_id IS NULL AND EXISTS (SELECT 1 FROM stores s WHERE s.name=c.store_name)
UNION ALL SELECT 'store_menu_cards', COUNT(*) FROM store_menu_cards c
  WHERE c.store_id IS NULL AND EXISTS (SELECT 1 FROM stores s WHERE s.name=c.store_name)
UNION ALL SELECT 'store_community_photos', COUNT(*) FROM store_community_photos c
  WHERE c.store_id IS NULL AND EXISTS (SELECT 1 FROM stores s WHERE s.name=c.store_name)
UNION ALL SELECT 'store_photos', COUNT(*) FROM store_photos c
  WHERE c.store_id IS NULL AND EXISTS (SELECT 1 FROM stores s WHERE s.name=c.store_name)
UNION ALL SELECT 'pin_ratings', COUNT(*) FROM pin_ratings c
  WHERE c.store_id IS NULL AND EXISTS (SELECT 1 FROM stores s WHERE s.name=c.store_name);
-- → 모든 unmatched 가 0 이면 성공.
--   (store_id 가 NULL 인데 stores 에 매칭이 아예 없는 행은 정상 — 가게 자체가 DB에 없는 고아 데이터)

-- ── 나중에 안정화되면 백업 스냅샷 정리(선택) ──
--   DROP TABLE IF EXISTS _bak2c_store_comments, _bak2c_store_menu_cards,
--     _bak2c_store_community_photos, _bak2c_store_photos, _bak2c_pin_ratings;
-- ════════════════════════════════════════════════════════════════════════════
