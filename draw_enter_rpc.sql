-- ════════════════════════════════════════════════════════════════════════════
-- 치리츠모 드로우 응모 — 서버 RPC (b447)
--   security_patch_v1.sql 이 draw_entries 의 UPDATE/DELETE 를 REVOKE 했으므로
--   응모(entry_count 누적 + 코인 차감)는 SECURITY DEFINER 함수로만 처리.
--   클라이언트는 enter_draw(p_draw_id) 만 호출.
--   Supabase SQL Editor 에서 실행 (idempotent).
-- ════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION enter_draw(p_draw_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid     UUID := auth.uid();
  v_draw    draws%ROWTYPE;
  v_entered INT;
  v_balance INT;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'err', 'auth');
  END IF;

  SELECT * INTO v_draw FROM draws WHERE id = p_draw_id AND is_active = TRUE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'err', 'not_found');
  END IF;

  -- 응모 기간
  IF now() < v_draw.starts_at OR now() > v_draw.ends_at THEN
    RETURN jsonb_build_object('ok', false, 'err', 'closed');
  END IF;

  -- 현재 누적 응모 횟수
  SELECT COALESCE(entry_count, 0) INTO v_entered
    FROM draw_entries WHERE draw_id = p_draw_id AND user_id = v_uid;
  v_entered := COALESCE(v_entered, 0);
  IF v_entered >= v_draw.max_entries_per_user THEN
    RETURN jsonb_build_object('ok', false, 'err', 'max_entries');
  END IF;

  -- 코인 잔액 확인 (행 잠금)
  SELECT COALESCE(coin_balance, 0) INTO v_balance
    FROM profiles WHERE id = v_uid FOR UPDATE;
  IF v_balance < v_draw.coin_cost THEN
    RETURN jsonb_build_object('ok', false, 'err', 'insufficient',
                              'balance', v_balance, 'cost', v_draw.coin_cost);
  END IF;

  -- 차감
  UPDATE profiles SET coin_balance = coin_balance - v_draw.coin_cost WHERE id = v_uid;
  INSERT INTO coin_transactions (user_id, amount, type, description)
    VALUES (v_uid, -v_draw.coin_cost, 'draw', 'チリドロー応募: ' || v_draw.title);

  -- 응모 누적 (UNIQUE(draw_id,user_id))
  INSERT INTO draw_entries (draw_id, user_id, entry_count)
    VALUES (p_draw_id, v_uid, 1)
  ON CONFLICT (draw_id, user_id)
    DO UPDATE SET entry_count = draw_entries.entry_count + 1;

  SELECT coin_balance INTO v_balance FROM profiles WHERE id = v_uid;
  RETURN jsonb_build_object('ok', true, 'balance', v_balance, 'entered', v_entered + 1);
END $$;

REVOKE ALL ON FUNCTION enter_draw(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION enter_draw(UUID) TO authenticated;

-- ════════════════════════════════════════════════════════════════════════════
-- 검증
--   SELECT enter_draw('<draw_id>');   -- 로그인 세션에서
-- ════════════════════════════════════════════════════════════════════════════
