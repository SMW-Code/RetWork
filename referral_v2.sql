-- ════════════════════════════════════════════════════════════════════════════
-- 추천(레퍼럴) 시스템 v2 — "대기 보상 + 광고 시청 후 청구" 모델
--
--   변경 핵심:
--     • 친구가 레퍼럴 링크로 가입 → 추천인에게 즉시 지급 X
--       → referral_rewards 테이블에 'pending(대기)' 1건 적립
--     • 추천인이 광고 1회 시청할 때마다 pending 1건씩 청구 → +200 coin_balance
--     • 1일 청구 상한 = 10건 (JST 자정 리셋) — 광고 단가 하락 대비 안전벨트
--     • 모든 청구가 광고 1회 = 보상 1건 → 항상 흑자(광고 ¥17 > 보상 ¥16)
--
--   ⚠️ 잔액 컬럼은 profiles.coin_balance (NOT coins). 코인 업데이트 전
--      set_config('app.admin_action','true') 로 트리거 우회 (client_add_coins 와 동일).
--
--   Supabase SQL Editor 에 그대로 붙여넣고 RUN. (idempotent)
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 대기/청구 보상 테이블 ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS referral_rewards (
  id           BIGSERIAL PRIMARY KEY,
  referrer_id  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  referee_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount       INT  NOT NULL DEFAULT 200,
  status       TEXT NOT NULL DEFAULT 'pending',   -- 'pending' | 'claimed'
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  claimed_at   TIMESTAMPTZ,
  CONSTRAINT referral_rewards_referee_uniq UNIQUE (referee_id)  -- 피추천인당 1건만
);

CREATE INDEX IF NOT EXISTS idx_refrew_referrer_status
  ON referral_rewards(referrer_id, status);
CREATE INDEX IF NOT EXISTS idx_refrew_referrer_claimed
  ON referral_rewards(referrer_id, claimed_at) WHERE status = 'claimed';

-- RLS: 직접 쓰기 금지(오직 SECURITY DEFINER RPC 경유), 본인 행만 조회 허용
ALTER TABLE referral_rewards ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY refrew_select_own ON referral_rewards
    FOR SELECT USING (referrer_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ── redeem_referral: 즉시 지급 → 대기 보상 적립으로 변경 ────────────────────
CREATE OR REPLACE FUNCTION redeem_referral(p_code TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_new_user UUID := auth.uid();
  v_referrer UUID;
  v_existing UUID;
BEGIN
  IF v_new_user IS NULL THEN
    RETURN json_build_object('ok', false, 'err', 'not_logged_in');
  END IF;
  IF p_code IS NULL OR length(p_code) < 4 THEN
    RETURN json_build_object('ok', false, 'err', 'bad_code');
  END IF;

  -- 유저당 1회만
  SELECT referred_by INTO v_existing FROM profiles WHERE id = v_new_user;
  IF v_existing IS NOT NULL THEN
    RETURN json_build_object('ok', false, 'err', 'already_redeemed');
  END IF;

  -- 추천 코드 → 추천인
  SELECT id INTO v_referrer FROM profiles WHERE upper(referral_code) = upper(p_code) LIMIT 1;
  IF v_referrer IS NULL THEN
    RETURN json_build_object('ok', false, 'err', 'code_not_found');
  END IF;
  IF v_referrer = v_new_user THEN
    RETURN json_build_object('ok', false, 'err', 'self_referral');
  END IF;

  -- 추천 관계 기록
  UPDATE profiles SET referred_by = v_referrer WHERE id = v_new_user;

  -- ★ 즉시 지급 대신 추천인에게 '대기 보상' 1건 적립 (광고 시청 후 청구)
  INSERT INTO referral_rewards(referrer_id, referee_id, amount, status)
    VALUES (v_referrer, v_new_user, 200, 'pending')
  ON CONFLICT ON CONSTRAINT referral_rewards_referee_uniq DO NOTHING;

  RETURN json_build_object('ok', true, 'referrer', v_referrer, 'pending', true);
END $$;

-- ── get_referral_status: 대기 건수 + 오늘 청구 수 + 상한 조회 ────────────────
CREATE OR REPLACE FUNCTION get_referral_status()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid           UUID := auth.uid();
  v_cap           INT  := 10;   -- 1일 청구 상한 (조정 가능)
  v_pending       INT;
  v_claimed_today INT;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('ok', false, 'err', 'not_logged_in');
  END IF;

  SELECT count(*) INTO v_pending
    FROM referral_rewards
   WHERE referrer_id = v_uid AND status = 'pending';

  SELECT count(*) INTO v_claimed_today
    FROM referral_rewards
   WHERE referrer_id = v_uid AND status = 'claimed'
     AND (claimed_at AT TIME ZONE 'Asia/Tokyo')::date
       = (now()       AT TIME ZONE 'Asia/Tokyo')::date;

  RETURN json_build_object(
    'ok', true,
    'pending', v_pending,
    'claimed_today', v_claimed_today,
    'cap', v_cap,
    'claimable_today', GREATEST(0, LEAST(v_pending, v_cap - v_claimed_today))
  );
END $$;

-- ── claim_referral_reward: 광고 시청 후 호출 → pending 1건 청구 → +200 ───────
CREATE OR REPLACE FUNCTION claim_referral_reward()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid           UUID := auth.uid();
  v_cap           INT  := 10;
  v_claimed_today INT;
  v_reward_id     BIGINT;
  v_balance       INT;
  v_pending_left  INT;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('ok', false, 'err', 'not_logged_in');
  END IF;

  -- 1일 상한 (JST)
  SELECT count(*) INTO v_claimed_today
    FROM referral_rewards
   WHERE referrer_id = v_uid AND status = 'claimed'
     AND (claimed_at AT TIME ZONE 'Asia/Tokyo')::date
       = (now()       AT TIME ZONE 'Asia/Tokyo')::date;

  IF v_claimed_today >= v_cap THEN
    RETURN json_build_object('ok', false, 'err', 'daily_cap', 'cap', v_cap);
  END IF;

  -- 가장 오래된 대기 보상 1건 잠금
  SELECT id INTO v_reward_id
    FROM referral_rewards
   WHERE referrer_id = v_uid AND status = 'pending'
   ORDER BY created_at ASC
   LIMIT 1
   FOR UPDATE SKIP LOCKED;

  IF v_reward_id IS NULL THEN
    RETURN json_build_object('ok', false, 'err', 'no_pending');
  END IF;

  -- 청구 처리
  UPDATE referral_rewards SET status = 'claimed', claimed_at = now() WHERE id = v_reward_id;

  -- 잔액 +200 (트리거 우회 + 올바른 컬럼 coin_balance)
  PERFORM set_config('app.admin_action', 'true', true);
  UPDATE profiles
     SET coin_balance = GREATEST(0, COALESCE(coin_balance, 0) + 200)
   WHERE id = v_uid
   RETURNING coin_balance INTO v_balance;

  -- 이력 기록
  BEGIN
    INSERT INTO coin_transactions(user_id, amount, type, description)
      VALUES (v_uid, 200, 'referral', '추천 보상 (광고 시청)');
  EXCEPTION WHEN undefined_table THEN NULL; WHEN undefined_column THEN NULL; END;

  SELECT count(*) INTO v_pending_left
    FROM referral_rewards WHERE referrer_id = v_uid AND status = 'pending';

  RETURN json_build_object(
    'ok', true,
    'amount', 200,
    'balance', v_balance,
    'pending', v_pending_left,
    'claimed_today', v_claimed_today + 1,
    'cap', v_cap
  );
END $$;

GRANT EXECUTE ON FUNCTION redeem_referral(TEXT)       TO authenticated;
GRANT EXECUTE ON FUNCTION get_referral_status()       TO authenticated;
GRANT EXECUTE ON FUNCTION claim_referral_reward()     TO authenticated;

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
-- 검증
--   SELECT redeem_referral('ABCD1234');     -- 친구 세션에서 (추천인에게 pending 1건)
--   SELECT get_referral_status();           -- 추천인 세션에서 (pending/claimable 확인)
--   SELECT claim_referral_reward();         -- 추천인 세션에서 (광고 후 호출 → +200)
--   SELECT referrer_id, status, count(*) FROM referral_rewards GROUP BY 1,2;
-- ════════════════════════════════════════════════════════════════════════════
