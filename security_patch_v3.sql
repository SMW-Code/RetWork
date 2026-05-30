-- ════════════════════════════════════════════════════════════════════════════
-- 보안 패치 v3 — 어뷰징 차단: type별 일일 한도 + 쿨다운
--
--   client_add_coins 를 강화. 양수(적립) 호출에 한해 type별 제한 적용:
--     • attendance: 하루 3회 / 쿨다운 없음
--     • ad        : 하루 5회 / 30초 간격
--     • bonus     : 하루 10회 / 쿨다운 없음 (연속 출석 보너스 등)
--     • post      : 하루 5회 / 60초 간격 (치리톡 게시글)
--     • pin       : 하루 5회 / 120초 간격 (수동 핀)
--     • photo     : 하루 3회 / 300초 간격 (메뉴 사진)
--     • publish   : 하루 3회 / 300초 간격 (영수증 공개)
--     • 그 외     : 제한 없음 (referral/shop/draw/scan/boost/admin_set)
--   음수(차감) 호출은 자유 통과.
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
  v_user          UUID := auth.uid();
  v_new           INT;
  v_count_today   INT;
  v_last_time     TIMESTAMPTZ;
  v_now           TIMESTAMPTZ := now();
  v_daily_limit   INT;
  v_cooldown_sec  INT;
  v_today_start   TIMESTAMPTZ := date_trunc('day', v_now);
BEGIN
  IF v_user IS NULL THEN
    RETURN json_build_object('ok',false,'err','not_logged_in');
  END IF;

  -- type 화이트리스트 (확장: post/pin/photo/publish 추가)
  IF p_type IS NULL OR p_type NOT IN (
    'attendance','ad','bonus','draw','shop','scan','referral','boost','admin_set',
    'post','pin','photo','publish'
  ) THEN
    RETURN json_build_object('ok',false,'err','invalid_type');
  END IF;

  IF p_amount IS NULL OR p_amount < -10000 OR p_amount > 10000 OR p_amount = 0 THEN
    RETURN json_build_object('ok',false,'err','amount_oob');
  END IF;

  -- 양수(적립) 만 rate limit 적용 — 음수(차감)는 자유
  IF p_amount > 0 THEN
    -- type 별 한도 결정
    CASE p_type
      WHEN 'attendance' THEN v_daily_limit := 3;    v_cooldown_sec := 0;
      WHEN 'ad'         THEN v_daily_limit := 5;    v_cooldown_sec := 30;
      WHEN 'bonus'      THEN v_daily_limit := 10;   v_cooldown_sec := 0;
      WHEN 'post'       THEN v_daily_limit := 5;    v_cooldown_sec := 60;
      WHEN 'pin'        THEN v_daily_limit := 5;    v_cooldown_sec := 120;
      WHEN 'photo'      THEN v_daily_limit := 3;    v_cooldown_sec := 300;
      WHEN 'publish'    THEN v_daily_limit := 3;    v_cooldown_sec := 300;
      ELSE v_daily_limit := NULL; v_cooldown_sec := NULL;  -- referral/shop/draw/scan/boost/admin_set
    END CASE;

    -- 일일 한도 체크
    IF v_daily_limit IS NOT NULL THEN
      SELECT COUNT(*) INTO v_count_today FROM coin_transactions
        WHERE user_id = v_user
          AND type = p_type
          AND amount > 0
          AND created_at >= v_today_start;
      IF v_count_today >= v_daily_limit THEN
        RETURN json_build_object('ok',false,'err','daily_limit','limit',v_daily_limit);
      END IF;
    END IF;

    -- 쿨다운 체크
    IF v_cooldown_sec IS NOT NULL AND v_cooldown_sec > 0 THEN
      SELECT MAX(created_at) INTO v_last_time FROM coin_transactions
        WHERE user_id = v_user
          AND type = p_type
          AND amount > 0;
      IF v_last_time IS NOT NULL AND (v_now - v_last_time) < (v_cooldown_sec * interval '1 second') THEN
        RETURN json_build_object(
          'ok',false,'err','cooldown',
          'retry_sec', v_cooldown_sec,
          'wait_sec', EXTRACT(EPOCH FROM (v_cooldown_sec * interval '1 second') - (v_now - v_last_time))::INT
        );
      END IF;
    END IF;
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
--   SELECT client_add_coins(1, 'post', '테스트');     -- 첫 호출 OK
--   SELECT client_add_coins(1, 'post', '테스트');     -- 60초 내 쿨다운 거부
--   SELECT type, COUNT(*) FROM coin_transactions
--     WHERE user_id = auth.uid() AND created_at >= date_trunc('day',now())
--     GROUP BY type;                                  -- 오늘 type별 카운트
-- ════════════════════════════════════════════════════════════════════════════
