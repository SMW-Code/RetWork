-- ════════════════════════════════════════════════════════════════════════════
-- 보안 패치 v2 — 어드민/일반 사용자의 합법적 변경을 위한 SECURITY DEFINER RPC
--
--   문제: security_patch_v1 의 트리거가 profiles.is_admin/coin_balance UPDATE를
--         service_role 외 전부 차단 → 어드민 UI 와 코인 적립이 깨짐.
--
--   해결: app.admin_action GUC 로 RPC 안에서만 bypass + 3가지 RPC 추가
--     • admin_set_user_admin(target, value)    — 어드민 권한 토글
--     • admin_set_user_coin (target, balance)  — 어드민 잔액 직접 설정
--     • client_add_coins   (amount, type, desc)— 일반 사용자 자기 코인 적립
--
-- Supabase SQL Editor 에 그대로 붙여넣고 RUN.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ─── [1] 트리거 업데이트: app.admin_action GUC 로 bypass 허용 ──────────────
CREATE OR REPLACE FUNCTION profiles_block_privileged_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- service_role (백엔드) 은 통과
  IF current_setting('request.jwt.claims', true)::jsonb->>'role' = 'service_role' THEN
    RETURN NEW;
  END IF;
  -- 우리가 만든 SECURITY DEFINER RPC 안에서만 set_config 로 활성화 → bypass
  IF current_setting('app.admin_action', true) = 'true' THEN
    RETURN NEW;
  END IF;

  IF NEW.is_admin IS DISTINCT FROM OLD.is_admin THEN
    RAISE EXCEPTION 'profiles.is_admin cannot be changed by client'
      USING ERRCODE = '42501';
  END IF;
  IF NEW.coin_balance IS DISTINCT FROM OLD.coin_balance THEN
    RAISE EXCEPTION 'profiles.coin_balance cannot be changed by client (use RPC)'
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END $$;

-- ─── [2] admin_set_user_admin — 어드민 권한 토글 (RPC + bypass) ─────────────
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
  SELECT p.is_admin INTO v_is_admin FROM profiles p WHERE p.id = v_caller;
  IF NOT COALESCE(v_is_admin, FALSE) THEN
    RETURN json_build_object('ok',false,'err','not_admin');
  END IF;
  -- 트리거 bypass 활성화 (트랜잭션 로컬)
  PERFORM set_config('app.admin_action', 'true', true);
  UPDATE profiles SET is_admin = COALESCE(p_value, FALSE) WHERE id = p_target;
  RETURN json_build_object('ok',true,'is_admin',p_value);
END $$;
GRANT EXECUTE ON FUNCTION admin_set_user_admin(UUID, BOOLEAN) TO authenticated;

-- ─── [3] admin_set_user_coin — 어드민이 다른 유저 코인 잔액 직접 설정 ─────
CREATE OR REPLACE FUNCTION admin_set_user_coin(p_target UUID, p_balance INT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller UUID := auth.uid();
  v_is_admin BOOLEAN;
  v_old INT;
  v_new INT;
BEGIN
  IF v_caller IS NULL THEN RETURN json_build_object('ok',false,'err','not_logged_in'); END IF;
  SELECT p.is_admin INTO v_is_admin FROM profiles p WHERE p.id = v_caller;
  IF NOT COALESCE(v_is_admin, FALSE) THEN
    RETURN json_build_object('ok',false,'err','not_admin');
  END IF;
  IF p_balance IS NULL OR p_balance < 0 THEN
    RETURN json_build_object('ok',false,'err','invalid_balance');
  END IF;
  SELECT coin_balance INTO v_old FROM profiles WHERE id = p_target;
  v_old := COALESCE(v_old, 0);
  v_new := p_balance;
  PERFORM set_config('app.admin_action', 'true', true);
  UPDATE profiles SET coin_balance = v_new WHERE id = p_target;
  -- 이력 기록 (변화량)
  BEGIN
    INSERT INTO coin_transactions(user_id, amount, type, description)
      VALUES (p_target, v_new - v_old, 'admin_set', '어드민 잔액 조정');
  EXCEPTION WHEN OTHERS THEN NULL; END;
  RETURN json_build_object('ok',true,'old',v_old,'new',v_new);
END $$;
GRANT EXECUTE ON FUNCTION admin_set_user_coin(UUID, INT) TO authenticated;

-- ─── [4] client_add_coins — 일반 사용자 자기 코인 적립 (제한된 type) ────────
-- 출석/광고/스캔 등 정상 적립 경로 — 화이트리스트 + 금액 sanity 검사
CREATE OR REPLACE FUNCTION client_add_coins(p_amount INT, p_type TEXT, p_description TEXT DEFAULT NULL)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_new  INT;
BEGIN
  IF v_user IS NULL THEN RETURN json_build_object('ok',false,'err','not_logged_in'); END IF;
  -- type 화이트리스트 — 그 외는 거부
  IF p_type IS NULL OR p_type NOT IN (
    'attendance','ad','bonus','draw','shop','scan','referral','boost','admin_set'
  ) THEN
    RETURN json_build_object('ok',false,'err','invalid_type');
  END IF;
  -- 한 번에 ±10,000 까지만 (악성 호출 차단)
  IF p_amount IS NULL OR p_amount < -10000 OR p_amount > 10000 OR p_amount = 0 THEN
    RETURN json_build_object('ok',false,'err','amount_oob');
  END IF;

  PERFORM set_config('app.admin_action', 'true', true);
  UPDATE profiles
    SET coin_balance = GREATEST(0, COALESCE(coin_balance, 0) + p_amount)
    WHERE id = v_user
    RETURNING coin_balance INTO v_new;

  INSERT INTO coin_transactions(user_id, amount, type, description)
    VALUES (v_user, p_amount, p_type, p_description);

  RETURN json_build_object('ok',true,'balance',v_new);
END $$;
GRANT EXECUTE ON FUNCTION client_add_coins(INT, TEXT, TEXT) TO authenticated;

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
-- 검증
--   SELECT client_add_coins(5, 'attendance', '출석 테스트');   -- 본인 세션
--   SELECT admin_set_user_admin('<uuid>', true);                -- 어드민 세션
--   SELECT admin_set_user_coin('<uuid>', 1000);                 -- 어드민 세션
-- ════════════════════════════════════════════════════════════════════════════
