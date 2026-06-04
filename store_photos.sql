-- ════════════════════════════════════════════════════════════════════════════
-- 가게 사진 + 메뉴 카드 사진 관리 (build 349)
--
--   store_photos       : 가게 외관/내부 사진 여러 장 (가게 1: 사진 N)
--   store_menu_photos  : 메뉴 카드별 사진 여러 장 (메뉴 1: 사진 N)
--
--   각 테이블에서 is_primary 컬럼으로 대표 사진 1장 지정 (UI 기본 표시 + 슬라이드 시작점).
--   sort_order 로 어드민이 순서 수동 배열, NULL 이면 created_at DESC 자동 정렬.
--
--   Supabase SQL Editor 에서 실행 (idempotent — 재실행 안전).
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ────────────────────────────────────────────────────────────────────────────
-- 1) store_photos
-- ────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS store_photos (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id     UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  image_url    TEXT NOT NULL,
  is_primary   BOOLEAN NOT NULL DEFAULT FALSE,
  sort_order   INTEGER,                                       -- NULL = created_at 순
  uploaded_by  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_store_photos_store_id   ON store_photos(store_id);
CREATE INDEX IF NOT EXISTS idx_store_photos_primary    ON store_photos(store_id, is_primary) WHERE is_primary = TRUE;
CREATE INDEX IF NOT EXISTS idx_store_photos_sort       ON store_photos(store_id, sort_order, created_at DESC);

-- 한 가게에 대표 사진은 최대 1장만
CREATE UNIQUE INDEX IF NOT EXISTS uq_store_photos_primary_one
  ON store_photos(store_id) WHERE is_primary = TRUE;

-- RLS
ALTER TABLE store_photos ENABLE ROW LEVEL SECURITY;

-- 모든 사용자 SELECT (가게 상세 페이지 표시)
DROP POLICY IF EXISTS "store_photos_select_all" ON store_photos;
CREATE POLICY "store_photos_select_all" ON store_photos
  FOR SELECT TO authenticated, anon
  USING (TRUE);

-- 어드민만 INSERT/UPDATE/DELETE
DROP POLICY IF EXISTS "store_photos_admin_insert" ON store_photos;
CREATE POLICY "store_photos_admin_insert" ON store_photos
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE)
  );

DROP POLICY IF EXISTS "store_photos_admin_update" ON store_photos;
CREATE POLICY "store_photos_admin_update" ON store_photos
  FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE)
  );

DROP POLICY IF EXISTS "store_photos_admin_delete" ON store_photos;
CREATE POLICY "store_photos_admin_delete" ON store_photos
  FOR DELETE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE)
  );


-- ────────────────────────────────────────────────────────────────────────────
-- 2) store_menu_photos (메뉴 카드 추가 사진)
--    ※ store_menu_cards.image_url 은 기존 흐름 유지 (대표 1장).
--      여기서는 어드민이 여러 장 추가하는 용도.
-- ────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS store_menu_photos (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  menu_card_id  UUID NOT NULL REFERENCES store_menu_cards(id) ON DELETE CASCADE,
  image_url     TEXT NOT NULL,
  is_primary    BOOLEAN NOT NULL DEFAULT FALSE,
  sort_order    INTEGER,
  uploaded_by   UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_store_menu_photos_card_id ON store_menu_photos(menu_card_id);
CREATE INDEX IF NOT EXISTS idx_store_menu_photos_primary ON store_menu_photos(menu_card_id, is_primary) WHERE is_primary = TRUE;
CREATE INDEX IF NOT EXISTS idx_store_menu_photos_sort    ON store_menu_photos(menu_card_id, sort_order, created_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS uq_store_menu_photos_primary_one
  ON store_menu_photos(menu_card_id) WHERE is_primary = TRUE;

ALTER TABLE store_menu_photos ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "store_menu_photos_select_all" ON store_menu_photos;
CREATE POLICY "store_menu_photos_select_all" ON store_menu_photos
  FOR SELECT TO authenticated, anon
  USING (TRUE);

DROP POLICY IF EXISTS "store_menu_photos_admin_insert" ON store_menu_photos;
CREATE POLICY "store_menu_photos_admin_insert" ON store_menu_photos
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE)
  );

DROP POLICY IF EXISTS "store_menu_photos_admin_update" ON store_menu_photos;
CREATE POLICY "store_menu_photos_admin_update" ON store_menu_photos
  FOR UPDATE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE)
  );

DROP POLICY IF EXISTS "store_menu_photos_admin_delete" ON store_menu_photos;
CREATE POLICY "store_menu_photos_admin_delete" ON store_menu_photos
  FOR DELETE TO authenticated
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE)
  );


-- ────────────────────────────────────────────────────────────────────────────
-- 3) store_menu_cards.sort_order 보강 (이미 존재할 수도)
--    어드민이 메뉴카드 순서 배열 시 사용
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE store_menu_cards
  ADD COLUMN IF NOT EXISTS sort_order INTEGER;

CREATE INDEX IF NOT EXISTS idx_store_menu_cards_sort
  ON store_menu_cards(store_name, sort_order, created_at DESC);

COMMIT;


-- ════════════════════════════════════════════════════════════════════════════
-- Storage Bucket 생성 (Supabase Dashboard → Storage)
--
--   1. Storage → New bucket
--   2. Name: store-photos
--   3. Public: ON (모든 사용자 조회 가능)
--   4. File size limit: 5 MB
--   5. Allowed MIME types: image/jpeg, image/png, image/webp, image/gif
--
--   ── Policies ──
--   SELECT: anyone (public bucket 이라 자동)
--   INSERT: authenticated AND profiles.is_admin = TRUE
--   UPDATE: authenticated AND profiles.is_admin = TRUE
--   DELETE: authenticated AND profiles.is_admin = TRUE
--
--   파일 경로 규칙 (어드민 UI 가 만들 때):
--     store-photos/<store_id>/<uuid>.<ext>
--     store-photos/menus/<menu_card_id>/<uuid>.<ext>
-- ════════════════════════════════════════════════════════════════════════════


-- ════════════════════════════════════════════════════════════════════════════
-- 검증 쿼리
--
--   SELECT * FROM store_photos LIMIT 5;
--   SELECT * FROM store_menu_photos LIMIT 5;
--   SELECT column_name FROM information_schema.columns
--     WHERE table_name = 'store_menu_cards' AND column_name = 'sort_order';
-- ════════════════════════════════════════════════════════════════════════════
