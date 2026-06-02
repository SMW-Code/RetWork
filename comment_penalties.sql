-- ════════════════════════════════════════════════════════════════════════════
-- 댓글 작성 패널티 (시간 제한)
--
--   • 어드민이 부적절 댓글 작성자에게 N시간 댓글 작성 금지 부여
--   • duration_hours = 1 / 6 / 12 / 24 / 72 / 168 / -1(영구) 등
--   • 활성 패널티가 있으면 ct_comments / store_comments INSERT 차단
--   • 누적 횟수 추적 → 블랙유저 전환 판단 자료
--
--   Supabase SQL Editor 에 그대로 붙여넣고 RUN (idempotent).
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE TABLE IF NOT EXISTS comment_penalties (
  id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID         NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  duration_hours  INT          NOT NULL,                  -- -1 = 영구
  reason          TEXT,
  starts_at       TIMESTAMPTZ  NOT NULL DEFAULT now(),
  ends_at         TIMESTAMPTZ,                            -- duration_hours=-1 이면 NULL (영구)
  admin_id        UUID         REFERENCES auth.users(id),
  related_comment TEXT,                                   -- 어떤 댓글 때문인지 스냅샷
  created_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cp_user_ends ON comment_penalties(user_id, ends_at DESC);
CREATE INDEX IF NOT EXISTS idx_cp_active   ON comment_penalties(user_id) WHERE ends_at IS NULL OR ends_at > now();

ALTER TABLE comment_penalties ENABLE ROW LEVEL SECURITY;

-- 본인 + 어드민 SELECT
DO $$ BEGIN
  CREATE POLICY cp_user_select ON comment_penalties FOR SELECT TO authenticated
    USING (
      user_id = auth.uid()
      OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 어드민만 INSERT/UPDATE/DELETE
DO $$ BEGIN
  CREATE POLICY cp_admin_all ON comment_penalties FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true))
    WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── 활성 패널티 조회 RPC ──
CREATE OR REPLACE FUNCTION get_active_comment_penalty()
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_p   RECORD;
BEGIN
  IF v_uid IS NULL THEN RETURN json_build_object('blocked', false); END IF;
  SELECT id, duration_hours, ends_at, reason
    INTO v_p
    FROM comment_penalties
   WHERE user_id = v_uid
     AND (ends_at IS NULL OR ends_at > now())
   ORDER BY ends_at DESC NULLS FIRST
   LIMIT 1;
  IF v_p.id IS NULL THEN RETURN json_build_object('blocked', false); END IF;
  RETURN json_build_object(
    'blocked', true,
    'duration_hours', v_p.duration_hours,
    'ends_at', v_p.ends_at,
    'reason', v_p.reason
  );
END $$;

-- ── 사용자 패널티 누적 카운트 RPC (어드민이 카드에서 확인) ──
CREATE OR REPLACE FUNCTION get_user_penalty_count(p_user_id UUID)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_total  INT;
  v_active INT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true) THEN
    RETURN json_build_object('ok', false, 'err', 'forbidden');
  END IF;
  SELECT COUNT(*) INTO v_total FROM comment_penalties WHERE user_id = p_user_id;
  SELECT COUNT(*) INTO v_active FROM comment_penalties
    WHERE user_id = p_user_id AND (ends_at IS NULL OR ends_at > now());
  RETURN json_build_object('ok', true, 'total', v_total, 'active', v_active);
END $$;

-- ── 어드민이 패널티 부여 RPC ──
CREATE OR REPLACE FUNCTION admin_grant_comment_penalty(
  p_user_id UUID, p_hours INT, p_reason TEXT, p_related TEXT
) RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_admin UUID := auth.uid();
  v_ends  TIMESTAMPTZ;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = v_admin AND is_admin = true) THEN
    RETURN json_build_object('ok', false, 'err', 'forbidden');
  END IF;
  IF p_hours = -1 THEN v_ends := NULL;
  ELSIF p_hours > 0 THEN v_ends := now() + (p_hours || ' hours')::interval;
  ELSE RETURN json_build_object('ok', false, 'err', 'invalid_hours'); END IF;
  INSERT INTO comment_penalties(user_id, duration_hours, reason, ends_at, admin_id, related_comment)
    VALUES (p_user_id, p_hours, p_reason, v_ends, v_admin, p_related);
  RETURN json_build_object('ok', true, 'ends_at', v_ends);
END $$;

GRANT EXECUTE ON FUNCTION get_active_comment_penalty()                                TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_penalty_count(UUID)                                TO authenticated;
GRANT EXECUTE ON FUNCTION admin_grant_comment_penalty(UUID, INT, TEXT, TEXT)          TO authenticated;

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
-- 검증
--   SELECT admin_grant_comment_penalty('<user-uid>', 24, '스팸성 댓글', '관련 댓글 내용');
--   SELECT get_active_comment_penalty();
--   SELECT get_user_penalty_count('<user-uid>');
-- ════════════════════════════════════════════════════════════════════════════
