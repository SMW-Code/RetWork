-- ════════════════════════════════════════════════════════════════════════════
-- #6 Phase 2a — 커뮤니티 테이블에 store_id 컬럼 추가 (dual-write 토대)
--
-- 목적: 지금 store_name(문자열)으로 묶인 커뮤니티 데이터를 장차 store_id 기준으로
--       전환하기 위한 첫 단계. **store_name 은 그대로 유지**하고 store_id 만 추가.
--       (NULL 허용 → 기존 동작·코드 그대로, 위험 거의 0)
--
-- 안전성: 순수 additive(컬럼 추가). 기존 데이터/읽기/쓰기 영향 없음.
-- FK: ON DELETE SET NULL → 가게 행이 사라져도 커뮤니티 데이터는 보존(연결만 해제).
--
-- Supabase SQL Editor 에 붙여넣고 RUN. (IF NOT EXISTS → 재실행 안전)
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

ALTER TABLE store_comments         ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES stores(id) ON DELETE SET NULL;
ALTER TABLE store_menu_cards       ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES stores(id) ON DELETE SET NULL;
ALTER TABLE store_community_photos ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES stores(id) ON DELETE SET NULL;
ALTER TABLE store_photos           ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES stores(id) ON DELETE SET NULL;
ALTER TABLE pin_ratings            ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES stores(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_store_comments_store_id         ON store_comments(store_id);
CREATE INDEX IF NOT EXISTS idx_store_menu_cards_store_id       ON store_menu_cards(store_id);
CREATE INDEX IF NOT EXISTS idx_store_community_photos_store_id ON store_community_photos(store_id);
CREATE INDEX IF NOT EXISTS idx_store_photos_store_id           ON store_photos(store_id);
CREATE INDEX IF NOT EXISTS idx_pin_ratings_store_id            ON pin_ratings(store_id);

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
-- 검증: 각 테이블에 store_id 컬럼이 생겼는지
--   SELECT table_name, column_name FROM information_schema.columns
--     WHERE column_name='store_id'
--       AND table_name IN ('store_comments','store_menu_cards',
--                          'store_community_photos','store_photos','pin_ratings');
--   → 5행 나오면 성공.
-- ════════════════════════════════════════════════════════════════════════════
