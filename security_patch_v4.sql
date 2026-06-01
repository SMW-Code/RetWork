-- ════════════════════════════════════════════════════════════════════════════
-- 보안 패치 v4 — 광고/보상 제한 임시 해제 (정식 출시 전 베타 운영용)
--
--   목적: 사용자 본인이 ランチ日記 시리즈 만들면서 광고/한도에 막히지 않게
--         정식 출시(v1.0.0) 직전에 security_patch_v3.sql 다시 실행하면 복원됨
--
--   변경 내용:
--     • client_add_coins 의 일일 한도 + 쿨다운 체크 제거
--     • type 화이트리스트 + amount sanity 체크는 유지 (보안 기본)
--     • set_config(app.admin_action) bypass 로직은 유지
--
-- Supabase SQL Editor 에 그대로 붙여넣고 RUN. (CREATE OR REPLACE)
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

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
  IF v_user IS NULL THEN
    RETURN json_build_object('ok',false,'err','not_logged_in');
  END IF;

  -- type 화이트리스트 (스팸 차단, 유지)
  IF p_type IS NULL OR p_type NOT IN (
    'attendance','ad','bonus','draw','shop','scan','referral','boost','admin_set',
    'post','pin','photo','publish'
  ) THEN
    RETURN json_build_object('ok',false,'err','invalid_type');
  END IF;

  -- amount sanity (악성 호출 차단, 유지)
  IF p_amount IS NULL OR p_amount < -10000 OR p_amount > 10000 OR p_amount = 0 THEN
    RETURN json_build_object('ok',false,'err','amount_oob');
  END IF;

  -- ⚠️ 일일 한도 + 쿨다운 체크 — 제거됨 (정식 출시 직전에 v3 재실행으로 복원)

  -- 트리거 bypass + 잔액 업데이트
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
--   SELECT client_add_coins(1, 'post', '테스트');     -- 1회
--   SELECT client_add_coins(1, 'post', '테스트');     -- 2회 (쿨다운 없음)
--   SELECT client_add_coins(1, 'post', '테스트');     -- ... 무제한
--   SELECT type, COUNT(*) FROM coin_transactions
--     WHERE user_id = auth.uid() AND created_at >= date_trunc('day',now())
--     GROUP BY type;
--
-- ⚠️ 정식 출시(v1.0.0) 직전에 security_patch_v3.sql 재실행하여 한도 복원!
-- ════════════════════════════════════════════════════════════════════════════
