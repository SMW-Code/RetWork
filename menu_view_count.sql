-- ════════════════════════════════════════════════════════════════════════════
-- 메뉴 카드 확인수(view_count) — 치리카드 탭용 (b448)
--   - store_menu_cards 에 view_count 컬럼 추가
--   - 메뉴 상세 열람 시 +1 (본인 카드 제외) — SECURITY DEFINER RPC
--     security_patch_v1.sql 이 store_menu_cards UPDATE 를 막으므로 RPC 필수
--   Supabase SQL Editor 에서 실행 (idempotent).
-- ════════════════════════════════════════════════════════════════════════════

ALTER TABLE store_menu_cards ADD COLUMN IF NOT EXISTS view_count INT DEFAULT 0;

CREATE OR REPLACE FUNCTION increment_menu_view(p_card_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- 본인이 만든 카드는 카운트하지 않음 (auth.uid() 가 NULL 이면 비로그인 → 카운트)
  UPDATE store_menu_cards
     SET view_count = COALESCE(view_count, 0) + 1
   WHERE id = p_card_id
     AND created_by IS DISTINCT FROM auth.uid();
END $$;

REVOKE ALL ON FUNCTION increment_menu_view(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION increment_menu_view(UUID) TO authenticated, anon;

-- ════════════════════════════════════════════════════════════════════════════
-- 검증
--   SELECT id, menu_name, view_count FROM store_menu_cards ORDER BY view_count DESC;
-- ════════════════════════════════════════════════════════════════════════════
