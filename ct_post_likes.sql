-- ════════════════════════════════════════════════════════════════════════════
-- 치리토크 게시글 좋아요 멱등성 — ct_post_likes 테이블 + 토글 RPC
--
--   문제: 기존엔 ct_posts.likes(카운트)만 증가시켜서, 상세를 다시 열 때마다
--         또 좋아요가 눌리고 매번 작성자에게 알림/푸시가 갔음 (멱등성 없음).
--   해결: 유저별 좋아요 기록 테이블(UNIQUE post_id+user_id) + 서버 토글 함수.
--         ct_posts.likes 는 실제 기록 수(COUNT)로 재계산 → 드리프트 없음.
--
--   Supabase SQL Editor 에 그대로 붙여넣고 RUN.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 좋아요 기록 테이블 ──
CREATE TABLE IF NOT EXISTS ct_post_likes (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id    UUID NOT NULL REFERENCES ct_posts(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (post_id, user_id)            -- ★ 멱등성 핵심: 한 유저는 한 게시글에 1개만
);

CREATE INDEX IF NOT EXISTS ct_post_likes_post_idx ON ct_post_likes (post_id);
CREATE INDEX IF NOT EXISTS ct_post_likes_user_idx ON ct_post_likes (user_id);

-- ── RLS ──
ALTER TABLE ct_post_likes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ct_post_likes_select ON ct_post_likes;
DROP POLICY IF EXISTS ct_post_likes_insert ON ct_post_likes;
DROP POLICY IF EXISTS ct_post_likes_delete ON ct_post_likes;

-- 읽기: 누구나 (좋아요 수/내 좋아요 상태 표시용)
CREATE POLICY ct_post_likes_select ON ct_post_likes
  FOR SELECT USING (true);
-- 삽입/삭제: 본인 것만
CREATE POLICY ct_post_likes_insert ON ct_post_likes
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY ct_post_likes_delete ON ct_post_likes
  FOR DELETE USING (auth.uid() = user_id);

-- ── 토글 RPC (원자적, 서버 권한) ──
--   이미 눌렀으면 → 삭제(좋아요 취소), 안 눌렀으면 → 추가
--   ct_posts.likes 는 항상 실제 기록 수로 재계산
--   반환: { ok, liked(현재 상태), count(현재 수) }
CREATE OR REPLACE FUNCTION toggle_post_like(p_post_id UUID)
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

  IF EXISTS (SELECT 1 FROM ct_post_likes WHERE post_id = p_post_id AND user_id = v_user) THEN
    DELETE FROM ct_post_likes WHERE post_id = p_post_id AND user_id = v_user;
    v_liked := false;
  ELSE
    INSERT INTO ct_post_likes (post_id, user_id) VALUES (p_post_id, v_user)
      ON CONFLICT (post_id, user_id) DO NOTHING;
    v_liked := true;
  END IF;

  SELECT COUNT(*) INTO v_count FROM ct_post_likes WHERE post_id = p_post_id;
  UPDATE ct_posts SET likes = v_count WHERE id = p_post_id;

  RETURN json_build_object('ok', true, 'liked', v_liked, 'count', v_count);
END $$;

GRANT EXECUTE ON FUNCTION toggle_post_like(UUID) TO authenticated;

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
-- 검증
--   SELECT toggle_post_like('<게시글 UUID>');   -- 1회: liked=true,  count=1
--   SELECT toggle_post_like('<게시글 UUID>');   -- 2회: liked=false, count=0 (취소)
--   SELECT toggle_post_like('<게시글 UUID>');   -- 3회: liked=true,  count=1 (다시)
--   SELECT post_id, COUNT(*) FROM ct_post_likes GROUP BY post_id;  -- 게시글별 실제 수
--
-- ※ 기존 ct_posts.likes 카운트는 유저별 기록이 없어서, 각 게시글이 처음
--    토글되는 시점에 실제 기록 수(보통 0~)로 재계산됨. (베타라 영향 미미)
-- ════════════════════════════════════════════════════════════════════════════
