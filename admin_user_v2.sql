-- ════════════════════════════════════════════════════════════════════════════
-- 어드민 사용자 관리 강화
--   1) admin_set_user_admin   : 어드민 권한 토글 RPC (RLS 우회)
--   2) admin_user_coin_history: 사용자 치리 내역 조회 (기간 필터)
--   3) admin_count_referred   : 추천 가입자 수 카운트
--
-- 모두 SECURITY DEFINER + 호출자가 admin 인지 검사.
-- Supabase SQL Editor 에 그대로 붙여넣고 RUN.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ─── 1) 어드민 권한 토글 RPC ─────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_set_user_admin(p_target UUID, p_value BOOLEAN)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_is_admin BOOLEAN;
BEGIN
  IF v_caller IS NULL THEN RETURN json_build_object('ok',false,'err','not_logged_in'); END IF;
  SELECT is_admin INTO v_is_admin FROM profiles WHERE id = v_caller;
  IF NOT COALESCE(v_is_admin, FALSE) THEN
    RETURN json_build_object('ok',false,'err','not_admin');
  END IF;
  UPDATE profiles SET is_admin = COALESCE(p_value, FALSE) WHERE id = p_target;
  RETURN json_build_object('ok',true,'is_admin',p_value);
END $$;
GRANT EXECUTE ON FUNCTION admin_set_user_admin(UUID, BOOLEAN) TO authenticated;

-- ─── 2) 사용자 치리 내역 조회 (기간 필터 + 페이지네이션) ──────────
-- coin_transactions 테이블이 있어야 함 (없으면 빈 결과 반환)
-- 시그니처 변경 시(파라미터 추가) DROP + CREATE 필요
DROP FUNCTION IF EXISTS admin_user_coin_history(UUID, TIMESTAMPTZ, TIMESTAMPTZ);
DROP FUNCTION IF EXISTS admin_user_coin_history(UUID, TIMESTAMPTZ, TIMESTAMPTZ, INT);
CREATE OR REPLACE FUNCTION admin_user_coin_history(
  p_user   UUID,
  p_from   TIMESTAMPTZ DEFAULT NULL,
  p_to     TIMESTAMPTZ DEFAULT NULL,
  p_offset INT DEFAULT 0,
  p_limit  INT DEFAULT 200
)
RETURNS TABLE(id UUID, amount INT, kind TEXT, note TEXT, created_at TIMESTAMPTZ)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_is_admin BOOLEAN;
BEGIN
  -- ⚠️ RETURNS TABLE 의 OUT 파라미터(id) 와 profiles.id 가 충돌하므로 반드시 명시
  SELECT p.is_admin INTO v_is_admin FROM profiles p WHERE p.id = v_caller;
  IF NOT COALESCE(v_is_admin, FALSE) THEN
    RAISE EXCEPTION 'admin only';
  END IF;
  RETURN QUERY
    SELECT ct.id, ct.amount, ct.kind, ct.note, ct.created_at
    FROM coin_transactions ct
    WHERE ct.user_id = p_user
      AND (p_from IS NULL OR ct.created_at >= p_from)
      AND (p_to   IS NULL OR ct.created_at <= p_to)
    ORDER BY ct.created_at DESC
    OFFSET GREATEST(p_offset, 0)
    LIMIT  LEAST(GREATEST(p_limit, 1), 500);
EXCEPTION WHEN undefined_table THEN
  RETURN;
END $$;
GRANT EXECUTE ON FUNCTION admin_user_coin_history(UUID, TIMESTAMPTZ, TIMESTAMPTZ, INT, INT) TO authenticated;

-- ─── 3) 추천 가입자 수 카운트 ────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_count_referred(p_user UUID)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_is_admin BOOLEAN;
  v_count INT;
BEGIN
  SELECT is_admin INTO v_is_admin FROM profiles WHERE id = v_caller;
  IF NOT COALESCE(v_is_admin, FALSE) THEN RETURN 0; END IF;
  SELECT COUNT(*)::INT INTO v_count FROM profiles WHERE referred_by = p_user;
  RETURN v_count;
END $$;
GRANT EXECUTE ON FUNCTION admin_count_referred(UUID) TO authenticated;

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
-- 검증 (어드민 세션으로 실행)
--   SELECT admin_set_user_admin('<uuid>', true);
--   SELECT * FROM admin_user_coin_history('<uuid>', NULL, NULL);
--   SELECT admin_count_referred('<uuid>');
-- ════════════════════════════════════════════════════════════════════════════
