-- ════════════════════════════════════════════════════════════════════════════
-- 가게 사진 + 메뉴 카드 사진 관리 (build 349, idempotent v3 — 기존 스키마 정합)
--
--   기존 store_photos 는 (store_name TEXT, photo_url TEXT, user_id UUID) 스키마.
--   이전 v1/v2 가 잘못 추가한 (store_id, image_url, uploaded_by) 중복 컬럼을 DROP 하고
--   기존 컬럼 위에 is_primary / sort_order 만 추가하여 일관 운영.
--
--   Supabase SQL Editor 에서 실행 (재실행 안전).
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ────────────────────────────────────────────────────────────────────────────
-- 1) store_photos 정리 (기존: store_name / photo_url / user_id 사용)
-- ────────────────────────────────────────────────────────────────────────────

-- 1-a) 빈 테이블이면 스켈레톤 생성 (드물지만 안전망)
CREATE TABLE IF NOT EXISTS store_photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid()
);

-- 1-b) 기존 컬럼 보강 (이미 있으면 noop)
ALTER TABLE store_photos ADD COLUMN IF NOT EXISTS store_name TEXT;
ALTER TABLE store_photos ADD COLUMN IF NOT EXISTS photo_url  TEXT;
ALTER TABLE store_photos ADD COLUMN IF NOT EXISTS user_id    UUID;
ALTER TABLE store_photos ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- 1-c) 신규 운영 컬럼 추가 (build 349 핵심)
ALTER TABLE store_photos ADD COLUMN IF NOT EXISTS is_primary BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE store_photos ADD COLUMN IF NOT EXISTS sort_order INTEGER;

-- 1-d) 이전 SQL v1/v2 가 잘못 추가했던 중복 컬럼 정리
--      (NULL 만 있는 빈 컬럼이라 안전하게 DROP)
DROP INDEX IF EXISTS idx_store_photos_store_id;
DROP INDEX IF EXISTS uq_store_photos_primary_one;  -- store_id 기반 unique → 잠시 제거 후 재생성

ALTER TABLE store_photos DROP CONSTRAINT IF EXISTS store_photos_store_id_fkey;
ALTER TABLE store_photos DROP CONSTRAINT IF EXISTS store_photos_uploaded_by_fkey;

ALTER TABLE store_photos DROP COLUMN IF EXISTS store_id;
ALTER TABLE store_photos DROP COLUMN IF EXISTS image_url;
ALTER TABLE store_photos DROP COLUMN IF EXISTS uploaded_by;

-- 1-e) FK (user_id → auth.users)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'store_photos_user_id_fkey'
  ) THEN
    ALTER TABLE store_photos
      ADD CONSTRAINT store_photos_user_id_fkey
      FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
  END IF;
END $$;

-- 1-f) 인덱스 (store_name 기준)
CREATE INDEX IF NOT EXISTS idx_store_photos_store_name ON store_photos(store_name);
CREATE INDEX IF NOT EXISTS idx_store_photos_primary    ON store_photos(store_name, is_primary) WHERE is_primary = TRUE;
CREATE INDEX IF NOT EXISTS idx_store_photos_sort       ON store_photos(store_name, sort_order, created_at DESC);
-- 가게당 대표 사진은 최대 1장
CREATE UNIQUE INDEX IF NOT EXISTS uq_store_photos_primary_one
  ON store_photos(store_name) WHERE is_primary = TRUE;

-- 1-g) RLS
ALTER TABLE store_photos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "store_photos_select_all"   ON store_photos;
DROP POLICY IF EXISTS "store_photos_admin_insert" ON store_photos;
DROP POLICY IF EXISTS "store_photos_admin_update" ON store_photos;
DROP POLICY IF EXISTS "store_photos_admin_delete" ON store_photos;

CREATE POLICY "store_photos_select_all" ON store_photos
  FOR SELECT TO authenticated, anon USING (TRUE);

CREATE POLICY "store_photos_admin_insert" ON store_photos
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE));

CREATE POLICY "store_photos_admin_update" ON store_photos
  FOR UPDATE TO authenticated
  USING      (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE));

CREATE POLICY "store_photos_admin_delete" ON store_photos
  FOR DELETE TO authenticated
  USING      (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE));


-- ────────────────────────────────────────────────────────────────────────────
-- 2) store_menu_photos (메뉴 카드 추가 사진)
--    이 테이블은 신규라 위 정리 불필요 — menu_card_id / image_url 기준 그대로.
-- ────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS store_menu_photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid()
);

ALTER TABLE store_menu_photos ADD COLUMN IF NOT EXISTS menu_card_id UUID;
ALTER TABLE store_menu_photos ADD COLUMN IF NOT EXISTS image_url    TEXT;
ALTER TABLE store_menu_photos ADD COLUMN IF NOT EXISTS is_primary   BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE store_menu_photos ADD COLUMN IF NOT EXISTS sort_order   INTEGER;
ALTER TABLE store_menu_photos ADD COLUMN IF NOT EXISTS uploaded_by  UUID;
ALTER TABLE store_menu_photos ADD COLUMN IF NOT EXISTS created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW();

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'store_menu_photos_card_fkey'
  ) THEN
    ALTER TABLE store_menu_photos
      ADD CONSTRAINT store_menu_photos_card_fkey
      FOREIGN KEY (menu_card_id) REFERENCES store_menu_cards(id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'store_menu_photos_uploaded_by_fkey'
  ) THEN
    ALTER TABLE store_menu_photos
      ADD CONSTRAINT store_menu_photos_uploaded_by_fkey
      FOREIGN KEY (uploaded_by) REFERENCES auth.users(id) ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_store_menu_photos_card_id ON store_menu_photos(menu_card_id);
CREATE INDEX IF NOT EXISTS idx_store_menu_photos_primary ON store_menu_photos(menu_card_id, is_primary) WHERE is_primary = TRUE;
CREATE INDEX IF NOT EXISTS idx_store_menu_photos_sort    ON store_menu_photos(menu_card_id, sort_order, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS uq_store_menu_photos_primary_one
  ON store_menu_photos(menu_card_id) WHERE is_primary = TRUE;

ALTER TABLE store_menu_photos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "store_menu_photos_select_all"   ON store_menu_photos;
DROP POLICY IF EXISTS "store_menu_photos_admin_insert" ON store_menu_photos;
DROP POLICY IF EXISTS "store_menu_photos_admin_update" ON store_menu_photos;
DROP POLICY IF EXISTS "store_menu_photos_admin_delete" ON store_menu_photos;

CREATE POLICY "store_menu_photos_select_all" ON store_menu_photos
  FOR SELECT TO authenticated, anon USING (TRUE);

CREATE POLICY "store_menu_photos_admin_insert" ON store_menu_photos
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE));

CREATE POLICY "store_menu_photos_admin_update" ON store_menu_photos
  FOR UPDATE TO authenticated
  USING      (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE));

CREATE POLICY "store_menu_photos_admin_delete" ON store_menu_photos
  FOR DELETE TO authenticated
  USING      (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE));


-- ────────────────────────────────────────────────────────────────────────────
-- 3) store_menu_cards.sort_order (어드민 메뉴 카드 순서 배열용)
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE store_menu_cards ADD COLUMN IF NOT EXISTS sort_order INTEGER;
CREATE INDEX IF NOT EXISTS idx_store_menu_cards_sort
  ON store_menu_cards(store_name, sort_order, created_at DESC);

COMMIT;


-- ════════════════════════════════════════════════════════════════════════════
-- 검증 쿼리 (실행 후 결과 확인)
--
--   기대: store_photos 컬럼 7개 — id / store_name / photo_url / user_id /
--                                  created_at / is_primary / sort_order
--   SELECT column_name, data_type FROM information_schema.columns
--     WHERE table_name = 'store_photos' ORDER BY ordinal_position;
--
--   기대: store_menu_photos 컬럼 7개
--   SELECT column_name, data_type FROM information_schema.columns
--     WHERE table_name = 'store_menu_photos' ORDER BY ordinal_position;
-- ════════════════════════════════════════════════════════════════════════════
