-- ════════════════════════════════════════════════════════════════════════════
-- 치리토크 베스트(인기) 게시글 — ct_posts.is_best + 어드민 토글 RPC
--
--   배너 상단 인기글 = (수동 지정 is_best) 우선 + (자동: 최근 좋아요·댓글 상위).
--   여기서는 수동 지정용 컬럼/함수만 추가. 자동 선정은 클라이언트가 점수로 계산.
--
--   Supabase SQL Editor 에 그대로 붙여넣고 RUN.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

ALTER TABLE ct_posts ADD COLUMN IF NOT EXISTS is_best BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS ct_posts_best_idx ON ct_posts (is_best) WHERE is_best = TRUE;

-- 어드민 전용 베스트 토글 (SECURITY DEFINER + is_admin 체크)
CREATE OR REPLACE FUNCTION set_post_best(p_post_id UUID, p_best BOOLEAN)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user UUID := auth.uid();
BEGIN
  IF v_user IS NULL OR NOT EXISTS (SELECT 1 FROM profiles WHERE id = v_user AND is_admin = TRUE) THEN
    RETURN json_build_object('ok', false, 'err', 'not_admin');
  END IF;
  UPDATE ct_posts SET is_best = p_best WHERE id = p_post_id;
  RETURN json_build_object('ok', true, 'is_best', p_best);
END $$;

GRANT EXECUTE ON FUNCTION set_post_best(UUID, BOOLEAN) TO authenticated;

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
-- 검증
--   SELECT set_post_best('<게시글 UUID>', true);    -- 베스트 등록 (어드민만 ok)
--   SELECT id, title, is_best, likes, comments FROM ct_posts WHERE is_best = TRUE;
-- ════════════════════════════════════════════════════════════════════════════
