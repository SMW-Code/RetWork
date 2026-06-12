-- ════════════════════════════════════════════════════════════════════════════
-- 메뉴 카드 좋아요 — menu_card_likes 테이블 + 토글 RPC (b451)
--   ct_post_likes 와 동일한 멱등 패턴. store_menu_cards.like_count 는 실제 수로 재계산.
--   Supabase SQL Editor 에 붙여넣고 RUN (idempotent).
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

ALTER TABLE store_menu_cards ADD COLUMN IF NOT EXISTS like_count INT DEFAULT 0;

CREATE TABLE IF NOT EXISTS menu_card_likes (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  menu_card_id UUID NOT NULL REFERENCES store_menu_cards(id) ON DELETE CASCADE,
  user_id      UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (menu_card_id, user_id)        -- 한 유저는 한 카드에 1개만
);
CREATE INDEX IF NOT EXISTS menu_card_likes_card_idx ON menu_card_likes (menu_card_id);
CREATE INDEX IF NOT EXISTS menu_card_likes_user_idx ON menu_card_likes (user_id);

ALTER TABLE menu_card_likes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS mcl_select ON menu_card_likes;
DROP POLICY IF EXISTS mcl_insert ON menu_card_likes;
DROP POLICY IF EXISTS mcl_delete ON menu_card_likes;
CREATE POLICY mcl_select ON menu_card_likes FOR SELECT USING (true);
CREATE POLICY mcl_insert ON menu_card_likes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY mcl_delete ON menu_card_likes FOR DELETE USING (auth.uid() = user_id);

-- 토글 RPC — 눌렀으면 취소, 아니면 추가. like_count 재계산. 반환 {ok,liked,count}
CREATE OR REPLACE FUNCTION toggle_menu_card_like(p_card_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user  UUID := auth.uid();
  v_liked BOOLEAN;
  v_count INT;
BEGIN
  IF v_user IS NULL THEN
    RETURN json_build_object('ok', false, 'err', 'not_logged_in');
  END IF;

  IF EXISTS (SELECT 1 FROM menu_card_likes WHERE menu_card_id = p_card_id AND user_id = v_user) THEN
    DELETE FROM menu_card_likes WHERE menu_card_id = p_card_id AND user_id = v_user;
    v_liked := false;
  ELSE
    INSERT INTO menu_card_likes (menu_card_id, user_id) VALUES (p_card_id, v_user)
      ON CONFLICT (menu_card_id, user_id) DO NOTHING;
    v_liked := true;
  END IF;

  SELECT COUNT(*) INTO v_count FROM menu_card_likes WHERE menu_card_id = p_card_id;
  UPDATE store_menu_cards SET like_count = v_count WHERE id = p_card_id;

  RETURN json_build_object('ok', true, 'liked', v_liked, 'count', v_count);
END $$;

REVOKE ALL ON FUNCTION toggle_menu_card_like(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION toggle_menu_card_like(UUID) TO authenticated;

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
-- 검증
--   SELECT id, menu_name, like_count FROM store_menu_cards ORDER BY like_count DESC;
-- ════════════════════════════════════════════════════════════════════════════
