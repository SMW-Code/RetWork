-- ════════════════════════════════════════════════════════════════════════════
-- 가게 사진 + 메뉴 카드 사진 관리 (build 349, idempotent v2)
--
--   기존에 store_photos / store_menu_photos 테이블이 다른 구조로 존재할 수 있어
--   ALTER TABLE ADD COLUMN IF NOT EXISTS 로 컬럼을 일일이 보강한 뒤
--   FK / INDEX / RLS 를 따로 적용한다.
--
--   Supabase SQL Editor 에서 실행 (재실행 안전).
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ────────────────────────────────────────────────────────────────────────────
-- 1) store_photos
-- ────────────────────────────────────────────────────────────────────────────

-- 1-a) 테이블 스켈레톤 (없으면 생성)
CREATE TABLE IF NOT EXISTS store_photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid()
);

-- 1-b) 필수 컬럼 보강
ALTER TABLE store_photos ADD COLUMN IF NOT EXISTS store_id    UUID;
ALTER TABLE store_photos ADD COLUMN IF NOT EXISTS image_url   TEXT;
ALTER TABLE store_photos ADD COLUMN IF NOT EXISTS is_primary  BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE store_photos ADD COLUMN IF NOT EXISTS sort_order  INTEGER;
ALTER TABLE store_photos ADD COLUMN IF NOT EXISTS uploaded_by UUID;
ALTER TABLE store_photos ADD COLUMN IF NOT EXISTS created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- 1-c) FK (없으면 추가)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'store_photos_store_id_fkey'
  ) THEN
    ALTER TABLE store_photos
      ADD CONSTRAINT store_photos_store_id_fkey
      FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'store_photos_uploaded_by_fkey'
  ) THEN
    ALTER TABLE store_photos
      ADD CONSTRAINT store_photos_uploaded_by_fkey
      FOREIGN KEY (uploaded_by) REFERENCES auth.users(id) ON DELETE SET NULL;
  END IF;
END $$;

-- 1-d) 인덱스
CREATE INDEX IF NOT EXISTS idx_store_photos_store_id ON store_photos(store_id);
CREATE INDEX IF NOT EXISTS idx_store_photos_primary  ON store_photos(store_id, is_primary) WHERE is_primary = TRUE;
CREATE INDEX IF NOT EXISTS idx_store_photos_sort     ON store_photos(store_id, sort_order, created_at DESC);
-- 가게당 대표 사진은 최대 1장
CREATE UNIQUE INDEX IF NOT EXISTS uq_store_photos_primary_one
  ON store_photos(store_id) WHERE is_primary = TRUE;

-- 1-e) RLS
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
-- 2) store_menu_photos
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
-- Storage Bucket (Supabase Dashboard → Storage 에서 수동 생성)
--   Name: store-photos
--   Public: ON
--   File size limit: 5 MB
--   Allowed MIME: image/jpeg, image/png, image/webp, image/gif
--   INSERT/UPDATE/DELETE Policy:
--     authenticated AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE)
-- ════════════════════════════════════════════════════════════════════════════


-- ════════════════════════════════════════════════════════════════════════════
-- 검증 쿼리
--   SELECT column_name, data_type FROM information_schema.columns
--     WHERE table_name = 'store_photos' ORDER BY ordinal_position;
--   SELECT column_name, data_type FROM information_schema.columns
--     WHERE table_name = 'store_menu_photos' ORDER BY ordinal_position;
--   SELECT * FROM store_photos LIMIT 1;
--   SELECT * FROM store_menu_photos LIMIT 1;
-- ════════════════════════════════════════════════════════════════════════════
