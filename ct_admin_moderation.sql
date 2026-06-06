-- ════════════════════════════════════════════════════════════════════════════
-- 치리토크 어드민 모더레이션 RLS 보강 — ct_posts / ct_comments
--
--   RLS 점검 결과: ct_posts DELETE/UPDATE 가 "본인만", ct_comments 는 DELETE 정책
--   자체가 없어서 → 어드민이 남의 게시글/댓글을 삭제할 수 없었음
--   (예전 "어드민 댓글 삭제가 안 먹는다" 버그의 원인).
--
--   보안 구멍이 아니라 과보호(운영 기능 누락) → 어드민 전용 정책을 OR 로 추가.
--   일반 유저는 그대로 본인 것만, 어드민은 전체 모더레이션 가능.
--
--   Supabase SQL Editor 에서 실행 (idempotent — DROP IF EXISTS 후 재생성).
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ct_posts: 어드민은 모든 게시글 수정/삭제 (기존 본인-only 정책과 OR 결합)
DROP POLICY IF EXISTS ct_posts_admin_all ON ct_posts;
CREATE POLICY ct_posts_admin_all ON ct_posts FOR ALL
  USING      (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true));

-- ct_comments: 본인 삭제 + 어드민 삭제 (기존엔 DELETE 정책이 없어 아무도 못 지움)
DROP POLICY IF EXISTS ct_comments_delete ON ct_comments;
CREATE POLICY ct_comments_delete ON ct_comments FOR DELETE
  USING (auth.uid() = user_id
         OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true));

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
-- 검증
--   SELECT tablename, cmd, policyname, qual
--   FROM pg_policies
--   WHERE schemaname='public' AND tablename IN ('ct_posts','ct_comments')
--   ORDER BY tablename, cmd;
--   → ct_posts 에 ct_posts_admin_all(ALL), ct_comments 에 ct_comments_delete(DELETE) 보이면 적용 완료
-- ════════════════════════════════════════════════════════════════════════════
