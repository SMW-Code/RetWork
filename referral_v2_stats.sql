-- ════════════════════════════════════════════════════════════════════════════
-- 추천 시스템 v2 — get_referral_status RPC 확장 (누적 통계 추가)
--
--   변경 핵심:
--     • total_referred:  추천한 총 친구 수 (referral_rewards.referrer_id = me)
--     • total_claimed:   누적 청구 완료 건수
--     • total_earned:    누적 받은 치리 (total_claimed × 200)
--
--   ⚠️ referral_v2.sql 먼저 실행 후 이 파일 실행.
--   idempotent (CREATE OR REPLACE) — 여러 번 실행해도 안전.
--
--   Supabase SQL Editor 에 그대로 붙여넣고 RUN.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE OR REPLACE FUNCTION get_referral_status()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid            UUID := auth.uid();
  v_cap            INT  := 10;   -- 1일 청구 상한
  v_pending        INT;
  v_total_claimed  INT;
  v_total_referred INT;
  v_claimed_today  INT;
BEGIN
  IF v_uid IS NULL THEN
    RETURN json_build_object('ok', false, 'err', 'not_logged_in');
  END IF;

  -- 한 번의 쿼리로 pending / claimed / total 한꺼번에 집계
  SELECT
    count(*) FILTER (WHERE status = 'pending'),
    count(*) FILTER (WHERE status = 'claimed'),
    count(*)
  INTO v_pending, v_total_claimed, v_total_referred
  FROM referral_rewards
  WHERE referrer_id = v_uid;

  -- 오늘 청구 카운트 (JST 자정 리셋)
  SELECT count(*) INTO v_claimed_today
    FROM referral_rewards
   WHERE referrer_id = v_uid AND status = 'claimed'
     AND (claimed_at AT TIME ZONE 'Asia/Tokyo')::date
       = (now()       AT TIME ZONE 'Asia/Tokyo')::date;

  RETURN json_build_object(
    'ok', true,
    -- 기존 필드 (호환 유지)
    'pending', v_pending,
    'claimed_today', v_claimed_today,
    'cap', v_cap,
    'claimable_today', GREATEST(0, LEAST(v_pending, v_cap - v_claimed_today)),
    -- ★ 신규: 누적 통계
    'total_referred', v_total_referred,
    'total_claimed',  v_total_claimed,
    'total_earned',   v_total_claimed * 200
  );
END $$;

GRANT EXECUTE ON FUNCTION get_referral_status() TO authenticated;

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
-- 검증
--   SELECT get_referral_status();
--   → 예: {
--       "ok": true,
--       "pending": 1, "claimed_today": 0, "cap": 10, "claimable_today": 1,
--       "total_referred": 3, "total_claimed": 2, "total_earned": 400
--     }
-- ════════════════════════════════════════════════════════════════════════════
