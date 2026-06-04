-- ════════════════════════════════════════════════════════════════════════════
-- 어드민 RLS 정책 보강 (build 351)
--
--   PostgREST .delete() / .update() 는 RLS 가 막아도 error 없이 0 rows 만 반환.
--   어드민 화면에서 "삭제됨" 토스트가 떠도 실제 행이 안 지워지는 케이스 방지.
--
--   영향 테이블:
--     - price_pins
--     - store_menu_cards
--     - store_menu_comments
--     - store_comments
--     - stores
--
--   Supabase SQL Editor 에서 실행 (idempotent).
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ────────────────────────────────────────────────────────────────────────────
-- price_pins — 어드민 DELETE/UPDATE 허용
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE price_pins ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "price_pins_admin_delete" ON price_pins;
CREATE POLICY "price_pins_admin_delete" ON price_pins
  FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE));

DROP POLICY IF EXISTS "price_pins_admin_update" ON price_pins;
CREATE POLICY "price_pins_admin_update" ON price_pins
  FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE));


-- ────────────────────────────────────────────────────────────────────────────
-- store_menu_cards — 어드민 INSERT/UPDATE/DELETE 허용
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE store_menu_cards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "store_menu_cards_admin_insert" ON store_menu_cards;
CREATE POLICY "store_menu_cards_admin_insert" ON store_menu_cards
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE));

DROP POLICY IF EXISTS "store_menu_cards_admin_update" ON store_menu_cards;
CREATE POLICY "store_menu_cards_admin_update" ON store_menu_cards
  FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE));

DROP POLICY IF EXISTS "store_menu_cards_admin_delete" ON store_menu_cards;
CREATE POLICY "store_menu_cards_admin_delete" ON store_menu_cards
  FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE));


-- ────────────────────────────────────────────────────────────────────────────
-- store_menu_comments — 어드민 DELETE 허용
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE store_menu_comments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "store_menu_comments_admin_delete" ON store_menu_comments;
CREATE POLICY "store_menu_comments_admin_delete" ON store_menu_comments
  FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE));


-- ────────────────────────────────────────────────────────────────────────────
-- store_comments (가게 단위 댓글) — 어드민 DELETE 허용
-- ────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'store_comments') THEN
    EXECUTE 'ALTER TABLE store_comments ENABLE ROW LEVEL SECURITY';
    EXECUTE 'DROP POLICY IF EXISTS "store_comments_admin_delete" ON store_comments';
    EXECUTE 'CREATE POLICY "store_comments_admin_delete" ON store_comments
      FOR DELETE TO authenticated
      USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE))';
  END IF;
END $$;


-- ────────────────────────────────────────────────────────────────────────────
-- receipts — 어드민 UPDATE/DELETE 허용 (build 362)
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE receipts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "receipts_admin_update" ON receipts;
CREATE POLICY "receipts_admin_update" ON receipts
  FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE));

DROP POLICY IF EXISTS "receipts_admin_delete" ON receipts;
CREATE POLICY "receipts_admin_delete" ON receipts
  FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE));

-- items 도 receipts CASCADE 가 안 걸려있다면 별도 정책 필요
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'items') THEN
    EXECUTE 'ALTER TABLE items ENABLE ROW LEVEL SECURITY';
    EXECUTE 'DROP POLICY IF EXISTS "items_admin_delete" ON items';
    EXECUTE 'CREATE POLICY "items_admin_delete" ON items
      FOR DELETE TO authenticated
      USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE))';
  END IF;
END $$;


-- ────────────────────────────────────────────────────────────────────────────
-- stores — 어드민 UPDATE/DELETE 허용
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE stores ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "stores_admin_update" ON stores;
CREATE POLICY "stores_admin_update" ON stores
  FOR UPDATE TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE));

DROP POLICY IF EXISTS "stores_admin_delete" ON stores;
CREATE POLICY "stores_admin_delete" ON stores
  FOR DELETE TO authenticated
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE));


COMMIT;


-- ════════════════════════════════════════════════════════════════════════════
-- 검증
--   SELECT polname, polcmd FROM pg_policy
--     WHERE polrelid IN ('price_pins'::regclass, 'store_menu_cards'::regclass,
--                        'store_menu_comments'::regclass, 'stores'::regclass)
--   ORDER BY polrelid, polcmd;
-- ════════════════════════════════════════════════════════════════════════════
