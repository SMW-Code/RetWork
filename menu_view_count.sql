-- ════════════════════════════════════════════════════════════════════════════
-- 메뉴 카드 확인수(view_count) — 치리카드 탭용 (b448 / b462 개정)
--   - store_menu_cards 에 view_count 컬럼
--   - increment_menu_view(p_card_id): 무조건 +1, 새 카운트 반환
--     (본인 카드 제외는 클라이언트에서 판단 — SECURITY DEFINER 안의 auth.uid()
--      의존을 제거해 확실하게 동작)
--   Supabase SQL Editor 에서 실행 (idempotent). ★ b462 에서 반환타입이 바뀌어
--   DROP 후 재생성합니다.
-- ════════════════════════════════════════════════════════════════════════════

ALTER TABLE store_menu_cards ADD COLUMN IF NOT EXISTS view_count INT DEFAULT 0;

DROP FUNCTION IF EXISTS increment_menu_view(UUID);

CREATE FUNCTION increment_menu_view(p_card_id UUID)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new INT;
BEGIN
  UPDATE store_menu_cards
     SET view_count = COALESCE(view_count, 0) + 1
   WHERE id = p_card_id
   RETURNING view_count INTO v_new;
  RETURN COALESCE(v_new, -1);  -- -1 = 해당 카드 없음
END $$;

REVOKE ALL ON FUNCTION increment_menu_view(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION increment_menu_view(UUID) TO authenticated, anon;

-- ════════════════════════════════════════════════════════════════════════════
-- 검증
--   SELECT increment_menu_view('<card_id>');   -- 호출할 때마다 +1, 새 값 반환
--   SELECT id, menu_name, view_count FROM store_menu_cards ORDER BY view_count DESC;
-- ════════════════════════════════════════════════════════════════════════════
