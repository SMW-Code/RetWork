-- ════════════════════════════════════════════════════════════════════════════
-- 치리토크 댓글 수 자동 동기화 — ct_posts.comments ← COUNT(ct_comments)
--
--   버그: 댓글 달 때 클라가 ct_posts.update({comments}) 로 카운트를 올렸는데,
--         ct_posts UPDATE 정책이 "본인 글만"이라 ★남의 글에 댓글 달면 RLS가 막아
--         카운트가 안 올라감 (4개 달려도 💬 0 으로 표시).
--   해결: ct_comments INSERT/DELETE 트리거로 ct_posts.comments 를 실제 수로 자동 재계산.
--         (SECURITY DEFINER → RLS 무관, 드리프트 없음). + 기존 드리프트 일괄 보정.
--
--   Supabase SQL Editor 에서 실행 (idempotent).
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE OR REPLACE FUNCTION _sync_ct_post_comment_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_post UUID;
BEGIN
  v_post := COALESCE(NEW.post_id, OLD.post_id);
  IF v_post IS NOT NULL THEN
    UPDATE ct_posts
      SET comments = (SELECT COUNT(*) FROM ct_comments WHERE post_id = v_post)
      WHERE id = v_post;
  END IF;
  RETURN NULL;
END $$;

DROP TRIGGER IF EXISTS ct_comments_count_trg ON ct_comments;
CREATE TRIGGER ct_comments_count_trg
  AFTER INSERT OR DELETE ON ct_comments
  FOR EACH ROW EXECUTE FUNCTION _sync_ct_post_comment_count();

-- 기존 드리프트 일괄 보정 (지금까지 안 맞던 카운트 전부 교정)
UPDATE ct_posts p
  SET comments = (SELECT COUNT(*) FROM ct_comments c WHERE c.post_id = p.id);

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
-- 검증
--   SELECT id, title, comments,
--          (SELECT COUNT(*) FROM ct_comments c WHERE c.post_id = ct_posts.id) AS real_cnt
--   FROM ct_posts ORDER BY created_at DESC LIMIT 10;
--   → comments 와 real_cnt 가 같아야 함
-- ════════════════════════════════════════════════════════════════════════════
