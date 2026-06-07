--
-- PostgreSQL database dump
--

-- (removed: \restrict meta-command — not needed for dev apply)

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.10

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

-- (removed: CREATE SCHEMA public — already exists on dev)


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

-- (removed: COMMENT ON SCHEMA public — avoids ownership error on dev)


--
-- Name: _announcements_set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public._announcements_set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;


--
-- Name: _check_banned_words(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public._check_banned_words() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  bw record;
  text_to_check text;
BEGIN
  IF TG_TABLE_NAME = 'ct_posts' THEN
    text_to_check := COALESCE(NEW.title, '') || ' ' || COALESCE(NEW.content, '');
  ELSE
    text_to_check := COALESCE(NEW.content, '');
  END IF;
  IF length(trim(text_to_check)) = 0 THEN RETURN NEW; END IF;
  FOR bw IN SELECT word FROM banned_words WHERE is_active = true AND severity = 'block' LOOP
    IF text_to_check ILIKE '%' || bw.word || '%' THEN
      RAISE EXCEPTION 'BANNED_WORD: %', bw.word;
    END IF;
  END LOOP;
  RETURN NEW;
END;
$$;


--
-- Name: _check_user_banned(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public._check_user_banned() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1 FROM banned_users
    WHERE user_id = auth.uid()
    AND is_active = true
    AND (expires_at IS NULL OR expires_at > now())
  ) THEN
    RAISE EXCEPTION 'USER_BANNED: 차단된 사용자는 작성할 수 없습니다';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: _exr_touch_updated(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public._exr_touch_updated() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END $$;


--
-- Name: _ps_touch_updated(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public._ps_touch_updated() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END $$;


--
-- Name: _psn_set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public._psn_set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;


--
-- Name: _quotes_touch_updated(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public._quotes_touch_updated() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END $$;


--
-- Name: _store_items_set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public._store_items_set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;


--
-- Name: add_coins(uuid, integer, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.add_coins(p_user_id uuid, p_amount integer, p_type text, p_desc text DEFAULT NULL::text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF current_setting('request.jwt.claims', true)::jsonb->>'role' <> 'service_role'
     AND p_user_id <> auth.uid() THEN
    RAISE EXCEPTION 'add_coins: cannot add coins to another user';
  END IF;

  INSERT INTO coin_transactions(user_id, amount, type, description)
  VALUES (p_user_id, p_amount, p_type, p_desc);

  UPDATE profiles
     SET coin_balance = coin_balance + p_amount
   WHERE id = p_user_id;
END;
$$;


--
-- Name: admin_broadcast_message(text, text, text, text, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_broadcast_message(p_title text, p_body text, p_priority text DEFAULT 'normal'::text, p_link_url text DEFAULT NULL::text, p_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_admin UUID := auth.uid();
  v_count INT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = v_admin AND is_admin = true) THEN
    RETURN json_build_object('ok', false, 'err', 'forbidden');
  END IF;
  IF p_title IS NULL OR length(trim(p_title)) = 0 OR p_body IS NULL OR length(trim(p_body)) = 0 THEN
    RETURN json_build_object('ok', false, 'err', 'invalid_input');
  END IF;
  IF p_priority NOT IN ('low','normal','high','urgent') THEN
    p_priority := 'normal';
  END IF;

  INSERT INTO admin_messages(recipient_id, sender_id, title, body, priority, link_url, expires_at)
  SELECT id, v_admin, p_title, p_body, p_priority, p_link_url, p_expires_at
    FROM profiles
   WHERE deleted_at IS NULL;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN json_build_object('ok', true, 'sent', v_count);
END $$;


--
-- Name: admin_count_referred(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_count_referred(p_user uuid) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: admin_get_user_email(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_get_user_email(uid uuid) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
BEGIN
  -- 호출자가 어드민인지 검증
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true) THEN
    RAISE EXCEPTION 'Permission denied: admin required';
  END IF;
  RETURN (SELECT email FROM auth.users WHERE id = uid);
END;
$$;


--
-- Name: admin_send_message(uuid[], text, text, text, text, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_send_message(p_recipient_ids uuid[], p_title text, p_body text, p_priority text DEFAULT 'normal'::text, p_link_url text DEFAULT NULL::text, p_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_admin UUID := auth.uid();
  v_count INT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = v_admin AND is_admin = true) THEN
    RETURN json_build_object('ok', false, 'err', 'forbidden');
  END IF;
  IF p_recipient_ids IS NULL OR array_length(p_recipient_ids, 1) IS NULL THEN
    RETURN json_build_object('ok', false, 'err', 'no_recipients');
  END IF;
  IF p_title IS NULL OR length(trim(p_title)) = 0 THEN
    RETURN json_build_object('ok', false, 'err', 'no_title');
  END IF;
  IF p_body IS NULL OR length(trim(p_body)) = 0 THEN
    RETURN json_build_object('ok', false, 'err', 'no_body');
  END IF;
  IF p_priority NOT IN ('low','normal','high','urgent') THEN
    p_priority := 'normal';
  END IF;

  INSERT INTO admin_messages(recipient_id, sender_id, title, body, priority, link_url, expires_at)
  SELECT unnest(p_recipient_ids), v_admin, p_title, p_body, p_priority, p_link_url, p_expires_at;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN json_build_object('ok', true, 'sent', v_count);
END $$;


--
-- Name: admin_set_user_admin(uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_set_user_admin(p_target uuid, p_value boolean) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: admin_set_user_coin(uuid, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_set_user_coin(p_target uuid, p_balance integer) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: admin_user_coin_history(uuid, timestamp with time zone, timestamp with time zone, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_user_coin_history(p_user uuid, p_from timestamp with time zone DEFAULT NULL::timestamp with time zone, p_to timestamp with time zone DEFAULT NULL::timestamp with time zone, p_offset integer DEFAULT 0, p_limit integer DEFAULT 200) RETURNS TABLE(id uuid, amount integer, kind text, note text, created_at timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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
  -- 실제 coin_transactions 컬럼: id, user_id, amount, type, description, created_at
  -- RPC 출력은 kind/note 로 alias 해서 클라 코드는 그대로 동작
  RETURN QUERY
    SELECT ct.id, ct.amount, ct.type AS kind, ct.description AS note, ct.created_at
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


--
-- Name: claim_referral_reward(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.claim_referral_reward() RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: client_add_coins(integer, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.client_add_coins(p_amount integer, p_type text, p_description text DEFAULT NULL::text) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: fn_item_price_comparison(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_item_price_comparison(p_item_name text) RETURNS TABLE(store_name text, avg_unit_price numeric, purchase_count bigint, lat double precision, lng double precision)
    LANGUAGE sql STABLE
    AS $$
  SELECT
    r.store_name,
    ROUND(AVG(i.price / NULLIF(i.quantity, 0)))          AS avg_unit_price,
    COUNT(*)                                             AS purchase_count,
    ROUND(AVG(r.lat)::NUMERIC, 6)::FLOAT                 AS lat,
    ROUND(AVG(r.lng)::NUMERIC, 6)::FLOAT                 AS lng
  FROM items i
  JOIN receipts r ON i.receipt_id = r.id
  WHERE LOWER(TRIM(i.name)) = LOWER(TRIM(p_item_name))
    AND i.price > 0
  GROUP BY r.store_name
  ORDER BY avg_unit_price ASC;
$$;


--
-- Name: fn_my_item_vs_avg(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_my_item_vs_avg(p_user_id uuid) RETURNS TABLE(item_name text, my_avg_price numeric, global_avg_price numeric, diff numeric, purchase_count bigint)
    LANGUAGE sql STABLE
    AS $$
  WITH my_items AS (
    SELECT
      LOWER(TRIM(i.name)) AS norm_name,
      i.name              AS item_name,
      ROUND(AVG(i.price / NULLIF(i.quantity, 0))) AS my_avg,
      COUNT(*)            AS cnt
    FROM items i
    JOIN receipts r ON i.receipt_id = r.id
    WHERE r.user_id = p_user_id AND i.price > 0
    GROUP BY LOWER(TRIM(i.name)), i.name
  ),
  global_items AS (
    SELECT
      LOWER(TRIM(i.name)) AS norm_name,
      ROUND(AVG(i.price / NULLIF(i.quantity, 0))) AS global_avg
    FROM items i
    JOIN receipts r ON i.receipt_id = r.id
    WHERE i.price > 0
    GROUP BY LOWER(TRIM(i.name))
  )
  SELECT
    m.item_name,
    m.my_avg                    AS my_avg_price,
    g.global_avg                AS global_avg_price,
    m.my_avg - g.global_avg     AS diff,
    m.cnt                       AS purchase_count
  FROM my_items m
  JOIN global_items g ON m.norm_name = g.norm_name
  ORDER BY ABS(m.my_avg - g.global_avg) DESC
  LIMIT 20;
$$;


--
-- Name: fn_nearby_store_stats(double precision, double precision, double precision); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_nearby_store_stats(center_lat double precision, center_lng double precision, radius_deg double precision DEFAULT 0.045) RETURNS TABLE(store_name text, visitor_count bigint, visit_count bigint, avg_spend numeric, last_visited text, lat double precision, lng double precision)
    LANGUAGE sql STABLE
    AS $$
  SELECT
    store_name,
    COUNT(DISTINCT user_id)          AS visitor_count,
    COUNT(*)                         AS visit_count,
    ROUND(AVG(total_amount))         AS avg_spend,
    MAX(receipt_date::TEXT)          AS last_visited,
    ROUND(AVG(lat)::NUMERIC, 6)::FLOAT AS lat,
    ROUND(AVG(lng)::NUMERIC, 6)::FLOAT AS lng
  FROM receipts
  WHERE lat IS NOT NULL
    AND lat BETWEEN center_lat - radius_deg AND center_lat + radius_deg
    AND lng BETWEEN center_lng - radius_deg AND center_lng + radius_deg
  GROUP BY store_name
  ORDER BY visitor_count DESC, avg_spend DESC;
$$;


--
-- Name: fn_store_item_stats(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_store_item_stats(p_store_name text) RETURNS TABLE(item_name text, purchase_count bigint, avg_unit_price numeric, min_unit_price numeric, max_unit_price numeric)
    LANGUAGE sql STABLE
    AS $$
  SELECT
    i.name                                              AS item_name,
    COUNT(*)                                            AS purchase_count,
    ROUND(AVG(i.price / NULLIF(i.quantity, 0)))         AS avg_unit_price,
    ROUND(MIN(i.price / NULLIF(i.quantity, 0)))         AS min_unit_price,
    ROUND(MAX(i.price / NULLIF(i.quantity, 0)))         AS max_unit_price
  FROM items i
  JOIN receipts r ON i.receipt_id = r.id
  WHERE r.store_name = p_store_name
    AND i.name IS NOT NULL
    AND i.price > 0
  GROUP BY i.name
  ORDER BY purchase_count DESC
  LIMIT 15;
$$;


--
-- Name: get_comment_quota_today(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_comment_quota_today() RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_user UUID := auth.uid();
  v_used INT;
  v_extra INT;
BEGIN
  IF v_user IS NULL THEN RETURN json_build_object('ok',false,'err','not_logged_in'); END IF;
  
  -- 오늘 작성한 댓글 (ct_comments + store_comments 합산)
  SELECT 
    (SELECT COUNT(*) FROM ct_comments 
     WHERE user_id = v_user AND created_at >= date_trunc('day', NOW()))
    +
    (SELECT COUNT(*) FROM store_comments 
     WHERE user_id = v_user AND created_at >= date_trunc('day', NOW()))
  INTO v_used;
  
  -- 오늘 받은 추가 권한 합산
  SELECT COALESCE(SUM(extra_count), 0) INTO v_extra
    FROM comment_quota_grants
    WHERE user_id = v_user AND grant_date = CURRENT_DATE;
  
  RETURN json_build_object(
    'ok', true,
    'used', v_used,
    'base_limit', 5,
    'extra_granted', v_extra,
    'total_limit', 5 + v_extra,
    'remaining', GREATEST(0, 5 + v_extra - v_used)
  );
END $$;


--
-- Name: get_referral_status(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_referral_status() RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: get_unread_admin_messages_count(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_unread_admin_messages_count() RETURNS integer
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE v_n INT;
BEGIN
  SELECT COUNT(*) INTO v_n FROM admin_messages
   WHERE recipient_id = auth.uid()
     AND is_read = false
     AND (expires_at IS NULL OR expires_at > now());
  RETURN COALESCE(v_n, 0);
END $$;


--
-- Name: grant_comment_quota(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.grant_comment_quota(p_extra integer) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE v_user UUID := auth.uid();
BEGIN
  IF v_user IS NULL THEN RETURN json_build_object('ok',false,'err','not_logged_in'); END IF;
  IF p_extra NOT IN (1, 4) THEN RETURN json_build_object('ok',false,'err','invalid_extra'); END IF;
  
  INSERT INTO comment_quota_grants(user_id, extra_count, source)
    VALUES (v_user, p_extra, 'ad');
  
  RETURN json_build_object('ok', true);
END $$;


--
-- Name: handle_new_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  new_code TEXT;
BEGIN
  new_code := upper(substring(gen_random_uuid()::text FROM 1 FOR 8));
  INSERT INTO public.profiles (id, nickname, referral_code)
  VALUES (NEW.id, '節約ユーザー', new_code)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RETURN NEW;  -- 트리거 실패해도 가입은 계속 진행
END;
$$;


--
-- Name: i18n_touch_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.i18n_touch_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  NEW.updated_by = auth.uid();
  RETURN NEW;
END;
$$;


--
-- Name: local_ad_bump(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.local_ad_bump(p_id uuid, p_kind text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  IF p_kind = 'click' THEN
    UPDATE local_ads SET clicks = clicks + 1 WHERE id = p_id;
  ELSE
    UPDATE local_ads SET impressions = impressions + 1 WHERE id = p_id;
  END IF;
END; $$;


--
-- Name: local_ads_touch(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.local_ads_touch() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$;


--
-- Name: mark_admin_message_read(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mark_admin_message_read(p_message_id uuid DEFAULT NULL::uuid) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE v_count INT;
BEGIN
  IF p_message_id IS NULL THEN
    UPDATE admin_messages
       SET is_read = true, read_at = now()
     WHERE recipient_id = auth.uid()
       AND is_read = false
       AND (expires_at IS NULL OR expires_at > now());
  ELSE
    UPDATE admin_messages
       SET is_read = true, read_at = now()
     WHERE id = p_message_id
       AND recipient_id = auth.uid()
       AND is_read = false;
  END IF;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN json_build_object('ok', true, 'updated', v_count);
END $$;


--
-- Name: notify_post_author(uuid, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notify_post_author(p_post_id uuid, p_type text, p_content text DEFAULT NULL::text, p_avatar text DEFAULT NULL::text) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_user      UUID := auth.uid();
  v_recipient UUID;
  v_title     TEXT;
  v_name      TEXT;
BEGIN
  IF v_user IS NULL THEN
    RETURN json_build_object('ok', false, 'err', 'not_logged_in');
  END IF;
  IF p_type NOT IN ('like', 'comment') THEN
    RETURN json_build_object('ok', false, 'err', 'invalid_type');
  END IF;

  -- 게시글 작성자 / 제목 조회
  SELECT user_id, title INTO v_recipient, v_title FROM ct_posts WHERE id = p_post_id;
  IF v_recipient IS NULL THEN
    RETURN json_build_object('ok', false, 'err', 'no_post');
  END IF;
  -- 본인 글이면 알림 안 보냄
  IF v_recipient = v_user THEN
    RETURN json_build_object('ok', true, 'skipped', 'self');
  END IF;

  -- 보낸사람 닉네임은 서버가 profiles 에서 (위조 불가). 아바타는 이모지라 클라값 허용.
  SELECT nickname INTO v_name FROM profiles WHERE id = v_user;

  INSERT INTO ct_notifications
    (recipient_id, type, post_id, post_title, from_user_id, from_user_name, from_user_avatar, content)
  VALUES
    (v_recipient, p_type, p_post_id, v_title, v_user, COALESCE(v_name, '名無し'), p_avatar, p_content);

  RETURN json_build_object('ok', true);
END $$;


--
-- Name: profiles_block_privileged_columns(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.profiles_block_privileged_columns() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
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


--
-- Name: profiles_set_referral_code(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.profiles_set_referral_code() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.referral_code IS NULL THEN
    NEW.referral_code := upper(substr(md5(random()::text || NEW.id::text), 1, 8));
  END IF;
  RETURN NEW;
END $$;


--
-- Name: psn_touch_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.psn_touch_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


--
-- Name: redeem_referral(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.redeem_referral(p_code text) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
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


--
-- Name: set_post_best(uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_post_best(p_post_id uuid, p_best boolean) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_user UUID := auth.uid();
BEGIN
  IF v_user IS NULL OR NOT EXISTS (SELECT 1 FROM profiles WHERE id = v_user AND is_admin = TRUE) THEN
    RETURN json_build_object('ok', false, 'err', 'not_admin');
  END IF;
  UPDATE ct_posts SET is_best = p_best WHERE id = p_post_id;
  RETURN json_build_object('ok', true, 'is_best', p_best);
END $$;


--
-- Name: toggle_post_like(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.toggle_post_like(p_post_id uuid) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_user  UUID := auth.uid();
  v_liked BOOLEAN;
  v_count INT;
BEGIN
  IF v_user IS NULL THEN
    RETURN json_build_object('ok', false, 'err', 'not_logged_in');
  END IF;

  IF EXISTS (SELECT 1 FROM ct_post_likes WHERE post_id = p_post_id AND user_id = v_user) THEN
    DELETE FROM ct_post_likes WHERE post_id = p_post_id AND user_id = v_user;
    v_liked := false;
  ELSE
    INSERT INTO ct_post_likes (post_id, user_id) VALUES (p_post_id, v_user)
      ON CONFLICT (post_id, user_id) DO NOTHING;
    v_liked := true;
  END IF;

  SELECT COUNT(*) INTO v_count FROM ct_post_likes WHERE post_id = p_post_id;
  UPDATE ct_posts SET likes = v_count WHERE id = p_post_id;

  RETURN json_build_object('ok', true, 'liked', v_liked, 'count', v_count);
END $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ad_missions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ad_missions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    date date DEFAULT CURRENT_DATE NOT NULL,
    count integer DEFAULT 0,
    last_watched_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: ad_revenue; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ad_revenue (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    month text NOT NULL,
    zone text DEFAULT 'all'::text NOT NULL,
    source text DEFAULT 'adsense'::text NOT NULL,
    amount_jpy numeric DEFAULT 0 NOT NULL,
    note text,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by uuid
);


--
-- Name: ad_views; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ad_views (
    id bigint NOT NULL,
    user_id uuid NOT NULL,
    ad_context text NOT NULL,
    reward_chiri integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ad_views_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ad_views_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ad_views_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ad_views_id_seq OWNED BY public.ad_views.id;


--
-- Name: admin_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    recipient_id uuid NOT NULL,
    sender_id uuid,
    title text NOT NULL,
    body text NOT NULL,
    priority text DEFAULT 'normal'::text NOT NULL,
    link_url text,
    is_read boolean DEFAULT false NOT NULL,
    read_at timestamp with time zone,
    expires_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT admin_messages_priority_check CHECK ((priority = ANY (ARRAY['low'::text, 'normal'::text, 'high'::text, 'urgent'::text])))
);


--
-- Name: announcements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.announcements (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title text NOT NULL,
    content text NOT NULL,
    banner_text text,
    type text DEFAULT 'info'::text,
    is_active boolean DEFAULT true,
    starts_at timestamp with time zone DEFAULT now(),
    ends_at timestamp with time zone,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT announcements_type_check CHECK ((type = ANY (ARRAY['info'::text, 'event'::text, 'urgent'::text])))
);


--
-- Name: attendance; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.attendance (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    date date DEFAULT CURRENT_DATE NOT NULL,
    streak integer DEFAULT 1,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: banned_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.banned_users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    reason text,
    banned_by uuid,
    banned_at timestamp with time zone DEFAULT now(),
    expires_at timestamp with time zone,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: banned_words; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.banned_words (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    word text NOT NULL,
    severity text DEFAULT 'block'::text,
    category text,
    is_active boolean DEFAULT true,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT banned_words_severity_check CHECK ((severity = ANY (ARRAY['block'::text, 'warn'::text])))
);


--
-- Name: coin_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.coin_transactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    amount integer NOT NULL,
    type text,
    description text,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT coin_transactions_type_check CHECK ((type = ANY (ARRAY['scan'::text, 'attendance'::text, 'ad'::text, 'referral'::text, 'draw'::text, 'shop'::text, 'boost'::text, 'bonus'::text])))
);


--
-- Name: comment_likes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comment_likes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    comment_id uuid,
    user_id uuid,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: comment_quota_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comment_quota_grants (
    id bigint NOT NULL,
    user_id uuid NOT NULL,
    grant_date date DEFAULT CURRENT_DATE NOT NULL,
    extra_count integer DEFAULT 0 NOT NULL,
    source text DEFAULT 'ad'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: comment_quota_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.comment_quota_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: comment_quota_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.comment_quota_grants_id_seq OWNED BY public.comment_quota_grants.id;


--
-- Name: comment_reports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comment_reports (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    comment_table text NOT NULL,
    comment_id uuid NOT NULL,
    comment_snapshot text,
    reporter_id uuid NOT NULL,
    reported_user_id uuid,
    reason text,
    reason_detail text,
    status text DEFAULT 'pending'::text,
    admin_note text,
    reviewed_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    reviewed_at timestamp with time zone,
    CONSTRAINT comment_reports_comment_table_check CHECK ((comment_table = ANY (ARRAY['store_comments'::text, 'store_menu_comments'::text, 'store_menu_replies'::text, 'ct_comments'::text, 'post_comments'::text]))),
    CONSTRAINT comment_reports_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'dismissed'::text, 'removed'::text])))
);


--
-- Name: ct_comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ct_comments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    post_id uuid NOT NULL,
    user_id uuid NOT NULL,
    user_name text DEFAULT '匿名'::text NOT NULL,
    user_avatar text DEFAULT '😊'::text,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: ct_notices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ct_notices (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    tag text DEFAULT 'お知らせ'::text,
    text text NOT NULL,
    bg_color text DEFAULT '#172C58'::text,
    text_color text DEFAULT '#FFFFFF'::text,
    tag_bg text DEFAULT 'rgba(232,160,32,.22)'::text,
    tag_color text DEFAULT '#E8A020'::text,
    font_size integer DEFAULT 13,
    image_url text,
    starts_at timestamp with time zone DEFAULT now(),
    ends_at timestamp with time zone,
    is_active boolean DEFAULT true,
    sort_order integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: ct_notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ct_notifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    recipient_id uuid NOT NULL,
    type text NOT NULL,
    post_id uuid,
    post_title text,
    from_user_name text,
    from_user_avatar text DEFAULT '😊'::text,
    content text,
    is_read boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    from_user_id uuid
);


--
-- Name: ct_post_likes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ct_post_likes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    post_id uuid NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: ct_posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ct_posts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    user_name text DEFAULT '節約ユーザー'::text NOT NULL,
    user_avatar text DEFAULT '😊'::text,
    cat text DEFAULT 'free'::text NOT NULL,
    title text NOT NULL,
    content text NOT NULL,
    likes integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    images jsonb DEFAULT '[]'::jsonb,
    comments integer DEFAULT 0,
    is_best boolean DEFAULT false
);


--
-- Name: draw_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.draw_entries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    draw_id uuid,
    user_id uuid,
    entry_count integer DEFAULT 1,
    is_winner boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: draws; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.draws (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title text NOT NULL,
    image_url text,
    coin_cost integer NOT NULL,
    max_entries_per_user integer DEFAULT 5,
    winner_count integer DEFAULT 2,
    starts_at timestamp with time zone NOT NULL,
    ends_at timestamp with time zone NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: exchange_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.exchange_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    item_id uuid,
    item_name text,
    item_image_url text,
    cost_chiri integer NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    delivery_info text,
    admin_note text,
    user_email text,
    user_nickname text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    processed_by uuid,
    processed_at timestamp with time zone
);


--
-- Name: i18n_translations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.i18n_translations (
    key text NOT NULL,
    lang text NOT NULL,
    value text NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by uuid,
    CONSTRAINT i18n_translations_lang_check CHECK ((lang = ANY (ARRAY['ja'::text, 'ko'::text, 'en'::text, 'zh'::text])))
);


--
-- Name: items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    receipt_id uuid,
    name text NOT NULL,
    quantity integer DEFAULT 1,
    price numeric,
    category text,
    created_at timestamp without time zone DEFAULT now(),
    product_id uuid
);


--
-- Name: kospa_votes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.kospa_votes (
    store_name text NOT NULL,
    user_id uuid NOT NULL,
    vote text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: local_ads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.local_ads (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title text NOT NULL,
    image_url text,
    link_url text,
    zone text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    start_at timestamp with time zone,
    end_at timestamp with time zone,
    sort_order integer DEFAULT 0 NOT NULL,
    impressions bigint DEFAULT 0 NOT NULL,
    clicks bigint DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    width_pct integer DEFAULT 100 NOT NULL,
    aspect_pct integer DEFAULT 40 NOT NULL,
    width_px integer,
    height_px integer
);


--
-- Name: pin_ratings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pin_ratings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    store_name text NOT NULL,
    user_id uuid NOT NULL,
    rating integer NOT NULL,
    has_receipt boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    menu_name text,
    CONSTRAINT pin_ratings_rating_check CHECK (((rating >= 1) AND (rating <= 5)))
);


--
-- Name: post_comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_comments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    post_id uuid,
    user_id uuid,
    content text NOT NULL,
    image_url text,
    like_count integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: post_likes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.post_likes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    post_id uuid,
    user_id uuid,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.posts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    category text DEFAULT 'free'::text,
    title text NOT NULL,
    content text NOT NULL,
    image_urls text[],
    like_count integer DEFAULT 0,
    comment_count integer DEFAULT 0,
    is_best boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT posts_category_check CHECK ((category = ANY (ARRAY['free'::text, 'humor'::text, 'fridge'::text, 'invest'::text, 'romance'::text, 'tips'::text])))
);


--
-- Name: price_pins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.price_pins (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    store_id uuid,
    receipt_id uuid,
    user_id uuid,
    item_name text,
    price integer NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    comment text DEFAULT ''::text
);


--
-- Name: private_store_notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.private_store_notes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    store_name text NOT NULL,
    sentiment text,
    note text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    rating smallint,
    CONSTRAINT private_store_notes_rating_check CHECK (((rating IS NULL) OR ((rating >= 1) AND (rating <= 10)))),
    CONSTRAINT private_store_notes_sentiment_check CHECK ((sentiment = ANY (ARRAY['love'::text, 'recommend'::text, 'neutral'::text, 'disappointing'::text, 'avoid'::text])))
);


--
-- Name: product_aliases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_aliases (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    product_id uuid,
    raw_text text NOT NULL,
    raw_normalized text,
    source_store text,
    user_id uuid,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: products_master; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.products_master (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    canonical text NOT NULL,
    brand text,
    category text,
    variant text,
    volume_value numeric,
    volume_unit text,
    match_count integer DEFAULT 1,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles (
    id uuid NOT NULL,
    nickname text DEFAULT '名無し'::text NOT NULL,
    referral_code text,
    referred_by uuid,
    level integer DEFAULT 0,
    coin_balance integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now(),
    is_admin boolean DEFAULT false,
    avatar_emoji text,
    avatar_url text,
    is_premium boolean DEFAULT false,
    premium_until timestamp with time zone,
    last_seen_at timestamp with time zone DEFAULT now(),
    deleted_at timestamp with time zone,
    budget_amount integer,
    budget_month text
);


--
-- Name: push_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.push_subscriptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    endpoint text NOT NULL,
    p256dh text NOT NULL,
    auth text NOT NULL,
    device_label text,
    user_agent text,
    enabled boolean DEFAULT true NOT NULL,
    last_sent_at timestamp with time zone,
    last_error text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    attendance_optin boolean DEFAULT true NOT NULL
);


--
-- Name: quotes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quotes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lang text NOT NULL,
    text text NOT NULL,
    author text,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    CONSTRAINT quotes_lang_check CHECK ((lang = ANY (ARRAY['ja'::text, 'ko'::text, 'en'::text, 'zh'::text])))
);


--
-- Name: receipts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.receipts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    store_name text,
    store_address text,
    receipt_date date,
    receipt_time time without time zone,
    total_amount numeric,
    payment_method text,
    image_url text,
    created_at timestamp without time zone DEFAULT now(),
    user_id uuid,
    lat numeric,
    lng numeric,
    is_public boolean DEFAULT false,
    place_id text,
    store_category text,
    memo text
);


--
-- Name: referral_rewards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.referral_rewards (
    id bigint NOT NULL,
    referrer_id uuid NOT NULL,
    referee_id uuid NOT NULL,
    amount integer DEFAULT 200 NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    claimed_at timestamp with time zone
);


--
-- Name: referral_rewards_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.referral_rewards_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: referral_rewards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.referral_rewards_id_seq OWNED BY public.referral_rewards.id;


--
-- Name: store_bookmarks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.store_bookmarks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    store_id uuid,
    user_id uuid,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: store_comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.store_comments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    store_name text NOT NULL,
    user_id uuid,
    user_name text DEFAULT 'ゲスト'::text,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    menu_name text,
    rating integer,
    has_receipt boolean DEFAULT false
);


--
-- Name: store_community_photos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.store_community_photos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    store_name text NOT NULL,
    photo_url text NOT NULL,
    uploaded_by uuid,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: store_edit_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.store_edit_requests (
    id bigint NOT NULL,
    store_id text,
    store_name text NOT NULL,
    lat double precision,
    lng double precision,
    user_id uuid,
    content text NOT NULL,
    status text DEFAULT 'open'::text NOT NULL,
    admin_note text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    resolved_at timestamp with time zone
);


--
-- Name: store_edit_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.store_edit_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: store_edit_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.store_edit_requests_id_seq OWNED BY public.store_edit_requests.id;


--
-- Name: store_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.store_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    description text,
    image_url text,
    cost_chiri integer NOT NULL,
    stock integer DEFAULT '-1'::integer,
    category text DEFAULT 'other'::text,
    is_active boolean DEFAULT true,
    sort_order integer DEFAULT 0,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT store_items_cost_chiri_check CHECK ((cost_chiri > 0))
);


--
-- Name: store_menu_cards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.store_menu_cards (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    store_name text NOT NULL,
    menu_name text NOT NULL,
    category text,
    price integer,
    image_url text,
    rating_avg numeric(3,1) DEFAULT 0,
    rating_count integer DEFAULT 0,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    is_featured boolean DEFAULT false,
    sort_order integer DEFAULT 0
);


--
-- Name: store_menu_comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.store_menu_comments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    menu_card_id uuid,
    user_id uuid,
    rating integer,
    content text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT store_menu_comments_rating_check CHECK (((rating >= 1) AND (rating <= 5)))
);


--
-- Name: store_menu_photos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.store_menu_photos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    menu_card_id uuid,
    image_url text,
    is_primary boolean DEFAULT false NOT NULL,
    sort_order integer,
    uploaded_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: store_menu_replies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.store_menu_replies (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    comment_id uuid,
    user_id uuid,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: store_photos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.store_photos (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    store_name text NOT NULL,
    photo_url text NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    is_primary boolean DEFAULT false NOT NULL,
    sort_order integer
);


--
-- Name: store_reactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.store_reactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    store_id uuid,
    user_id uuid,
    reaction text,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT store_reactions_reaction_check CHECK ((reaction = ANY (ARRAY['cheap'::text, 'expensive'::text, 'good_value'::text])))
);


--
-- Name: stores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stores (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    address text,
    lat numeric,
    lng numeric,
    business_number text,
    created_at timestamp without time zone DEFAULT now(),
    place_id text,
    category text,
    receipt_count integer DEFAULT 0,
    avg_price integer DEFAULT 0,
    google_maps_url text,
    featured_price integer,
    featured_menu_name text
);


--
-- Name: ad_views id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_views ALTER COLUMN id SET DEFAULT nextval('public.ad_views_id_seq'::regclass);


--
-- Name: comment_quota_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment_quota_grants ALTER COLUMN id SET DEFAULT nextval('public.comment_quota_grants_id_seq'::regclass);


--
-- Name: referral_rewards id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referral_rewards ALTER COLUMN id SET DEFAULT nextval('public.referral_rewards_id_seq'::regclass);


--
-- Name: store_edit_requests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_edit_requests ALTER COLUMN id SET DEFAULT nextval('public.store_edit_requests_id_seq'::regclass);


--
-- Name: ad_missions ad_missions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_missions
    ADD CONSTRAINT ad_missions_pkey PRIMARY KEY (id);


--
-- Name: ad_missions ad_missions_user_id_date_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_missions
    ADD CONSTRAINT ad_missions_user_id_date_key UNIQUE (user_id, date);


--
-- Name: ad_revenue ad_revenue_month_zone_source_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_revenue
    ADD CONSTRAINT ad_revenue_month_zone_source_key UNIQUE (month, zone, source);


--
-- Name: ad_revenue ad_revenue_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_revenue
    ADD CONSTRAINT ad_revenue_pkey PRIMARY KEY (id);


--
-- Name: ad_views ad_views_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_views
    ADD CONSTRAINT ad_views_pkey PRIMARY KEY (id);


--
-- Name: admin_messages admin_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_messages
    ADD CONSTRAINT admin_messages_pkey PRIMARY KEY (id);


--
-- Name: announcements announcements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcements
    ADD CONSTRAINT announcements_pkey PRIMARY KEY (id);


--
-- Name: attendance attendance_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT attendance_pkey PRIMARY KEY (id);


--
-- Name: attendance attendance_user_id_date_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT attendance_user_id_date_key UNIQUE (user_id, date);


--
-- Name: banned_users banned_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.banned_users
    ADD CONSTRAINT banned_users_pkey PRIMARY KEY (id);


--
-- Name: banned_users banned_users_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.banned_users
    ADD CONSTRAINT banned_users_user_id_key UNIQUE (user_id);


--
-- Name: banned_words banned_words_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.banned_words
    ADD CONSTRAINT banned_words_pkey PRIMARY KEY (id);


--
-- Name: banned_words banned_words_word_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.banned_words
    ADD CONSTRAINT banned_words_word_key UNIQUE (word);


--
-- Name: coin_transactions coin_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coin_transactions
    ADD CONSTRAINT coin_transactions_pkey PRIMARY KEY (id);


--
-- Name: comment_likes comment_likes_comment_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment_likes
    ADD CONSTRAINT comment_likes_comment_id_user_id_key UNIQUE (comment_id, user_id);


--
-- Name: comment_likes comment_likes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment_likes
    ADD CONSTRAINT comment_likes_pkey PRIMARY KEY (id);


--
-- Name: comment_quota_grants comment_quota_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment_quota_grants
    ADD CONSTRAINT comment_quota_grants_pkey PRIMARY KEY (id);


--
-- Name: comment_reports comment_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment_reports
    ADD CONSTRAINT comment_reports_pkey PRIMARY KEY (id);


--
-- Name: ct_comments ct_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ct_comments
    ADD CONSTRAINT ct_comments_pkey PRIMARY KEY (id);


--
-- Name: ct_notices ct_notices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ct_notices
    ADD CONSTRAINT ct_notices_pkey PRIMARY KEY (id);


--
-- Name: ct_notifications ct_notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ct_notifications
    ADD CONSTRAINT ct_notifications_pkey PRIMARY KEY (id);


--
-- Name: ct_post_likes ct_post_likes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ct_post_likes
    ADD CONSTRAINT ct_post_likes_pkey PRIMARY KEY (id);


--
-- Name: ct_post_likes ct_post_likes_post_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ct_post_likes
    ADD CONSTRAINT ct_post_likes_post_id_user_id_key UNIQUE (post_id, user_id);


--
-- Name: ct_posts ct_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ct_posts
    ADD CONSTRAINT ct_posts_pkey PRIMARY KEY (id);


--
-- Name: draw_entries draw_entries_draw_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.draw_entries
    ADD CONSTRAINT draw_entries_draw_id_user_id_key UNIQUE (draw_id, user_id);


--
-- Name: draw_entries draw_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.draw_entries
    ADD CONSTRAINT draw_entries_pkey PRIMARY KEY (id);


--
-- Name: draws draws_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.draws
    ADD CONSTRAINT draws_pkey PRIMARY KEY (id);


--
-- Name: exchange_requests exchange_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exchange_requests
    ADD CONSTRAINT exchange_requests_pkey PRIMARY KEY (id);


--
-- Name: i18n_translations i18n_translations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.i18n_translations
    ADD CONSTRAINT i18n_translations_pkey PRIMARY KEY (key, lang);


--
-- Name: items items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.items
    ADD CONSTRAINT items_pkey PRIMARY KEY (id);


--
-- Name: kospa_votes kospa_votes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.kospa_votes
    ADD CONSTRAINT kospa_votes_pkey PRIMARY KEY (store_name, user_id);


--
-- Name: local_ads local_ads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.local_ads
    ADD CONSTRAINT local_ads_pkey PRIMARY KEY (id);


--
-- Name: pin_ratings pin_ratings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pin_ratings
    ADD CONSTRAINT pin_ratings_pkey PRIMARY KEY (id);


--
-- Name: pin_ratings pin_ratings_store_name_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pin_ratings
    ADD CONSTRAINT pin_ratings_store_name_user_id_key UNIQUE (store_name, user_id);


--
-- Name: post_comments post_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_comments
    ADD CONSTRAINT post_comments_pkey PRIMARY KEY (id);


--
-- Name: post_likes post_likes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_likes
    ADD CONSTRAINT post_likes_pkey PRIMARY KEY (id);


--
-- Name: post_likes post_likes_post_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_likes
    ADD CONSTRAINT post_likes_post_id_user_id_key UNIQUE (post_id, user_id);


--
-- Name: posts posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: price_pins price_pins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_pins
    ADD CONSTRAINT price_pins_pkey PRIMARY KEY (id);


--
-- Name: private_store_notes private_store_notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.private_store_notes
    ADD CONSTRAINT private_store_notes_pkey PRIMARY KEY (id);


--
-- Name: private_store_notes private_store_notes_user_id_store_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.private_store_notes
    ADD CONSTRAINT private_store_notes_user_id_store_name_key UNIQUE (user_id, store_name);


--
-- Name: product_aliases product_aliases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_aliases
    ADD CONSTRAINT product_aliases_pkey PRIMARY KEY (id);


--
-- Name: products_master products_master_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products_master
    ADD CONSTRAINT products_master_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_referral_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_referral_code_key UNIQUE (referral_code);


--
-- Name: push_subscriptions push_subscriptions_endpoint_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_subscriptions
    ADD CONSTRAINT push_subscriptions_endpoint_key UNIQUE (endpoint);


--
-- Name: push_subscriptions push_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_subscriptions
    ADD CONSTRAINT push_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: quotes quotes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotes
    ADD CONSTRAINT quotes_pkey PRIMARY KEY (id);


--
-- Name: receipts receipts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receipts
    ADD CONSTRAINT receipts_pkey PRIMARY KEY (id);


--
-- Name: referral_rewards referral_rewards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referral_rewards
    ADD CONSTRAINT referral_rewards_pkey PRIMARY KEY (id);


--
-- Name: referral_rewards referral_rewards_referee_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referral_rewards
    ADD CONSTRAINT referral_rewards_referee_uniq UNIQUE (referee_id);


--
-- Name: store_bookmarks store_bookmarks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_bookmarks
    ADD CONSTRAINT store_bookmarks_pkey PRIMARY KEY (id);


--
-- Name: store_bookmarks store_bookmarks_store_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_bookmarks
    ADD CONSTRAINT store_bookmarks_store_id_user_id_key UNIQUE (store_id, user_id);


--
-- Name: store_comments store_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_comments
    ADD CONSTRAINT store_comments_pkey PRIMARY KEY (id);


--
-- Name: store_community_photos store_community_photos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_community_photos
    ADD CONSTRAINT store_community_photos_pkey PRIMARY KEY (id);


--
-- Name: store_edit_requests store_edit_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_edit_requests
    ADD CONSTRAINT store_edit_requests_pkey PRIMARY KEY (id);


--
-- Name: store_items store_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_items
    ADD CONSTRAINT store_items_pkey PRIMARY KEY (id);


--
-- Name: store_menu_cards store_menu_cards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_menu_cards
    ADD CONSTRAINT store_menu_cards_pkey PRIMARY KEY (id);


--
-- Name: store_menu_comments store_menu_comments_menu_card_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_menu_comments
    ADD CONSTRAINT store_menu_comments_menu_card_id_user_id_key UNIQUE (menu_card_id, user_id);


--
-- Name: store_menu_comments store_menu_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_menu_comments
    ADD CONSTRAINT store_menu_comments_pkey PRIMARY KEY (id);


--
-- Name: store_menu_photos store_menu_photos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_menu_photos
    ADD CONSTRAINT store_menu_photos_pkey PRIMARY KEY (id);


--
-- Name: store_menu_replies store_menu_replies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_menu_replies
    ADD CONSTRAINT store_menu_replies_pkey PRIMARY KEY (id);


--
-- Name: store_photos store_photos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_photos
    ADD CONSTRAINT store_photos_pkey PRIMARY KEY (id);


--
-- Name: store_reactions store_reactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_reactions
    ADD CONSTRAINT store_reactions_pkey PRIMARY KEY (id);


--
-- Name: store_reactions store_reactions_store_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_reactions
    ADD CONSTRAINT store_reactions_store_id_user_id_key UNIQUE (store_id, user_id);


--
-- Name: stores stores_name_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stores
    ADD CONSTRAINT stores_name_unique UNIQUE (name);


--
-- Name: stores stores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stores
    ADD CONSTRAINT stores_pkey PRIMARY KEY (id);


--
-- Name: coin_tx_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX coin_tx_user_idx ON public.coin_transactions USING btree (user_id, created_at DESC);


--
-- Name: comments_post_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX comments_post_id_idx ON public.post_comments USING btree (post_id);


--
-- Name: ct_notices_active_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ct_notices_active_idx ON public.ct_notices USING btree (is_active, sort_order, created_at DESC);


--
-- Name: ct_post_likes_post_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ct_post_likes_post_idx ON public.ct_post_likes USING btree (post_id);


--
-- Name: ct_post_likes_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ct_post_likes_user_idx ON public.ct_post_likes USING btree (user_id);


--
-- Name: ct_posts_best_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ct_posts_best_idx ON public.ct_posts USING btree (is_best) WHERE (is_best = true);


--
-- Name: idx_ad_revenue_month; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ad_revenue_month ON public.ad_revenue USING btree (month);


--
-- Name: idx_ad_views_context; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ad_views_context ON public.ad_views USING btree (ad_context);


--
-- Name: idx_ad_views_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ad_views_created ON public.ad_views USING btree (created_at DESC);


--
-- Name: idx_ad_views_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ad_views_user ON public.ad_views USING btree (user_id);


--
-- Name: idx_am_expires; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_am_expires ON public.admin_messages USING btree (expires_at) WHERE (expires_at IS NOT NULL);


--
-- Name: idx_am_recipient_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_am_recipient_created ON public.admin_messages USING btree (recipient_id, created_at DESC);


--
-- Name: idx_am_recipient_unread; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_am_recipient_unread ON public.admin_messages USING btree (recipient_id, is_read);


--
-- Name: idx_am_sender_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_am_sender_created ON public.admin_messages USING btree (sender_id, created_at DESC);


--
-- Name: idx_announcements_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_announcements_active ON public.announcements USING btree (is_active, starts_at, ends_at);


--
-- Name: idx_comment_reports_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_comment_reports_status ON public.comment_reports USING btree (status, created_at DESC);


--
-- Name: idx_comment_reports_target; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_comment_reports_target ON public.comment_reports USING btree (comment_table, comment_id);


--
-- Name: idx_cqg_user_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cqg_user_date ON public.comment_quota_grants USING btree (user_id, grant_date);


--
-- Name: idx_exr_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_exr_status ON public.exchange_requests USING btree (status, created_at DESC);


--
-- Name: idx_exr_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_exr_user ON public.exchange_requests USING btree (user_id, created_at DESC);


--
-- Name: idx_i18n_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_i18n_key ON public.i18n_translations USING btree (key);


--
-- Name: idx_i18n_lang; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_i18n_lang ON public.i18n_translations USING btree (lang);


--
-- Name: idx_items_product; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_items_product ON public.items USING btree (product_id);


--
-- Name: idx_local_ads_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_local_ads_active ON public.local_ads USING btree (is_active);


--
-- Name: idx_local_ads_zone; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_local_ads_zone ON public.local_ads USING btree (zone);


--
-- Name: idx_pinrat_menu; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_pinrat_menu ON public.pin_ratings USING btree (store_name, user_id, menu_name) WHERE (menu_name IS NOT NULL);


--
-- Name: idx_product_aliases_raw; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_product_aliases_raw ON public.product_aliases USING btree (raw_normalized);


--
-- Name: idx_products_canonical; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_products_canonical ON public.products_master USING btree (canonical);


--
-- Name: idx_products_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_products_category ON public.products_master USING btree (category);


--
-- Name: idx_profiles_referral_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_profiles_referral_code ON public.profiles USING btree (referral_code) WHERE (referral_code IS NOT NULL);


--
-- Name: idx_profiles_referred_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_profiles_referred_by ON public.profiles USING btree (referred_by) WHERE (referred_by IS NOT NULL);


--
-- Name: idx_ps_attendance_optin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ps_attendance_optin ON public.push_subscriptions USING btree (attendance_optin) WHERE ((enabled = true) AND (attendance_optin = true));


--
-- Name: idx_ps_endpoint; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ps_endpoint ON public.push_subscriptions USING btree (endpoint);


--
-- Name: idx_ps_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ps_user ON public.push_subscriptions USING btree (user_id, enabled);


--
-- Name: idx_psn_user_store; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_psn_user_store ON public.private_store_notes USING btree (user_id, store_name);


--
-- Name: idx_quotes_lang_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_quotes_lang_active ON public.quotes USING btree (lang, is_active, sort_order);


--
-- Name: idx_refrew_referrer_claimed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_refrew_referrer_claimed ON public.referral_rewards USING btree (referrer_id, claimed_at) WHERE (status = 'claimed'::text);


--
-- Name: idx_refrew_referrer_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_refrew_referrer_status ON public.referral_rewards USING btree (referrer_id, status);


--
-- Name: idx_ser_status_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ser_status_created ON public.store_edit_requests USING btree (status, created_at DESC);


--
-- Name: idx_store_items_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_store_items_active ON public.store_items USING btree (is_active, sort_order);


--
-- Name: idx_store_menu_cards_sort; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_store_menu_cards_sort ON public.store_menu_cards USING btree (store_name, sort_order, created_at DESC);


--
-- Name: idx_store_menu_photos_card_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_store_menu_photos_card_id ON public.store_menu_photos USING btree (menu_card_id);


--
-- Name: idx_store_menu_photos_primary; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_store_menu_photos_primary ON public.store_menu_photos USING btree (menu_card_id, is_primary) WHERE (is_primary = true);


--
-- Name: idx_store_menu_photos_sort; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_store_menu_photos_sort ON public.store_menu_photos USING btree (menu_card_id, sort_order, created_at DESC);


--
-- Name: idx_store_photos_primary; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_store_photos_primary ON public.store_photos USING btree (store_name, is_primary) WHERE (is_primary = true);


--
-- Name: idx_store_photos_sort; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_store_photos_sort ON public.store_photos USING btree (store_name, sort_order, created_at DESC);


--
-- Name: idx_store_photos_store_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_store_photos_store_name ON public.store_photos USING btree (store_name);


--
-- Name: posts_category_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX posts_category_idx ON public.posts USING btree (category);


--
-- Name: posts_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX posts_created_at_idx ON public.posts USING btree (created_at DESC);


--
-- Name: price_pins_store_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX price_pins_store_id_idx ON public.price_pins USING btree (store_id);


--
-- Name: stores_lat_lng_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX stores_lat_lng_idx ON public.stores USING btree (lat, lng);


--
-- Name: stores_place_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX stores_place_id_idx ON public.stores USING btree (place_id);


--
-- Name: uq_store_menu_photos_primary_one; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_store_menu_photos_primary_one ON public.store_menu_photos USING btree (menu_card_id) WHERE (is_primary = true);


--
-- Name: uq_store_photos_primary_one; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_store_photos_primary_one ON public.store_photos USING btree (store_name) WHERE (is_primary = true);


--
-- Name: announcements announcements_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER announcements_updated_at BEFORE UPDATE ON public.announcements FOR EACH ROW EXECUTE FUNCTION public._announcements_set_updated_at();


--
-- Name: ct_comments check_banned_user_ct_comments; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER check_banned_user_ct_comments BEFORE INSERT ON public.ct_comments FOR EACH ROW EXECUTE FUNCTION public._check_user_banned();


--
-- Name: ct_posts check_banned_user_ct_posts; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER check_banned_user_ct_posts BEFORE INSERT ON public.ct_posts FOR EACH ROW EXECUTE FUNCTION public._check_user_banned();


--
-- Name: price_pins check_banned_user_price_pins; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER check_banned_user_price_pins BEFORE INSERT ON public.price_pins FOR EACH ROW EXECUTE FUNCTION public._check_user_banned();


--
-- Name: store_comments check_banned_user_store_comments; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER check_banned_user_store_comments BEFORE INSERT ON public.store_comments FOR EACH ROW EXECUTE FUNCTION public._check_user_banned();


--
-- Name: store_community_photos check_banned_user_store_community_photos; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER check_banned_user_store_community_photos BEFORE INSERT ON public.store_community_photos FOR EACH ROW EXECUTE FUNCTION public._check_user_banned();


--
-- Name: store_menu_cards check_banned_user_store_menu_cards; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER check_banned_user_store_menu_cards BEFORE INSERT ON public.store_menu_cards FOR EACH ROW EXECUTE FUNCTION public._check_user_banned();


--
-- Name: store_menu_comments check_banned_user_store_menu_comments; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER check_banned_user_store_menu_comments BEFORE INSERT ON public.store_menu_comments FOR EACH ROW EXECUTE FUNCTION public._check_user_banned();


--
-- Name: store_menu_replies check_banned_user_store_menu_replies; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER check_banned_user_store_menu_replies BEFORE INSERT ON public.store_menu_replies FOR EACH ROW EXECUTE FUNCTION public._check_user_banned();


--
-- Name: ct_comments check_banned_words_ct_comments; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER check_banned_words_ct_comments BEFORE INSERT OR UPDATE ON public.ct_comments FOR EACH ROW EXECUTE FUNCTION public._check_banned_words();


--
-- Name: ct_posts check_banned_words_ct_posts; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER check_banned_words_ct_posts BEFORE INSERT OR UPDATE ON public.ct_posts FOR EACH ROW EXECUTE FUNCTION public._check_banned_words();


--
-- Name: store_comments check_banned_words_store_comments; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER check_banned_words_store_comments BEFORE INSERT OR UPDATE ON public.store_comments FOR EACH ROW EXECUTE FUNCTION public._check_banned_words();


--
-- Name: store_menu_comments check_banned_words_store_menu_comments; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER check_banned_words_store_menu_comments BEFORE INSERT OR UPDATE ON public.store_menu_comments FOR EACH ROW EXECUTE FUNCTION public._check_banned_words();


--
-- Name: store_menu_replies check_banned_words_store_menu_replies; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER check_banned_words_store_menu_replies BEFORE INSERT OR UPDATE ON public.store_menu_replies FOR EACH ROW EXECUTE FUNCTION public._check_banned_words();


--
-- Name: exchange_requests exr_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER exr_updated_at BEFORE UPDATE ON public.exchange_requests FOR EACH ROW EXECUTE FUNCTION public._exr_touch_updated();


--
-- Name: i18n_translations i18n_touch_updated_at_trg; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER i18n_touch_updated_at_trg BEFORE INSERT OR UPDATE ON public.i18n_translations FOR EACH ROW EXECUTE FUNCTION public.i18n_touch_updated_at();


--
-- Name: local_ads local_ads_touch_trg; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER local_ads_touch_trg BEFORE UPDATE ON public.local_ads FOR EACH ROW EXECUTE FUNCTION public.local_ads_touch();


--
-- Name: profiles profiles_block_privileged_columns_trg; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER profiles_block_privileged_columns_trg BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.profiles_block_privileged_columns();


--
-- Name: profiles profiles_set_referral_code_trg; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER profiles_set_referral_code_trg BEFORE INSERT ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.profiles_set_referral_code();


--
-- Name: push_subscriptions ps_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER ps_updated_at BEFORE UPDATE ON public.push_subscriptions FOR EACH ROW EXECUTE FUNCTION public._ps_touch_updated();


--
-- Name: private_store_notes psn_touch_updated_at_trg; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER psn_touch_updated_at_trg BEFORE UPDATE ON public.private_store_notes FOR EACH ROW EXECUTE FUNCTION public.psn_touch_updated_at();


--
-- Name: private_store_notes psn_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER psn_updated_at BEFORE UPDATE ON public.private_store_notes FOR EACH ROW EXECUTE FUNCTION public._psn_set_updated_at();


--
-- Name: quotes quotes_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER quotes_updated_at BEFORE UPDATE ON public.quotes FOR EACH ROW EXECUTE FUNCTION public._quotes_touch_updated();


--
-- Name: store_items store_items_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER store_items_updated_at BEFORE UPDATE ON public.store_items FOR EACH ROW EXECUTE FUNCTION public._store_items_set_updated_at();


--
-- Name: ad_missions ad_missions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_missions
    ADD CONSTRAINT ad_missions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: ad_revenue ad_revenue_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_revenue
    ADD CONSTRAINT ad_revenue_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: ad_views ad_views_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_views
    ADD CONSTRAINT ad_views_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: admin_messages admin_messages_recipient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_messages
    ADD CONSTRAINT admin_messages_recipient_id_fkey FOREIGN KEY (recipient_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: admin_messages admin_messages_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_messages
    ADD CONSTRAINT admin_messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES auth.users(id);


--
-- Name: announcements announcements_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcements
    ADD CONSTRAINT announcements_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: attendance attendance_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attendance
    ADD CONSTRAINT attendance_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: banned_users banned_users_banned_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.banned_users
    ADD CONSTRAINT banned_users_banned_by_fkey FOREIGN KEY (banned_by) REFERENCES auth.users(id);


--
-- Name: banned_users banned_users_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.banned_users
    ADD CONSTRAINT banned_users_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: banned_words banned_words_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.banned_words
    ADD CONSTRAINT banned_words_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: coin_transactions coin_transactions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coin_transactions
    ADD CONSTRAINT coin_transactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: comment_likes comment_likes_comment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment_likes
    ADD CONSTRAINT comment_likes_comment_id_fkey FOREIGN KEY (comment_id) REFERENCES public.post_comments(id) ON DELETE CASCADE;


--
-- Name: comment_likes comment_likes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment_likes
    ADD CONSTRAINT comment_likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: comment_quota_grants comment_quota_grants_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment_quota_grants
    ADD CONSTRAINT comment_quota_grants_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: comment_reports comment_reports_reported_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment_reports
    ADD CONSTRAINT comment_reports_reported_user_id_fkey FOREIGN KEY (reported_user_id) REFERENCES auth.users(id);


--
-- Name: comment_reports comment_reports_reporter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment_reports
    ADD CONSTRAINT comment_reports_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES auth.users(id);


--
-- Name: comment_reports comment_reports_reviewed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment_reports
    ADD CONSTRAINT comment_reports_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES auth.users(id);


--
-- Name: ct_comments ct_comments_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ct_comments
    ADD CONSTRAINT ct_comments_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.ct_posts(id) ON DELETE CASCADE;


--
-- Name: ct_post_likes ct_post_likes_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ct_post_likes
    ADD CONSTRAINT ct_post_likes_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.ct_posts(id) ON DELETE CASCADE;


--
-- Name: ct_post_likes ct_post_likes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ct_post_likes
    ADD CONSTRAINT ct_post_likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: ct_posts ct_posts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ct_posts
    ADD CONSTRAINT ct_posts_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: draw_entries draw_entries_draw_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.draw_entries
    ADD CONSTRAINT draw_entries_draw_id_fkey FOREIGN KEY (draw_id) REFERENCES public.draws(id) ON DELETE CASCADE;


--
-- Name: draw_entries draw_entries_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.draw_entries
    ADD CONSTRAINT draw_entries_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: exchange_requests exchange_requests_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exchange_requests
    ADD CONSTRAINT exchange_requests_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.store_items(id) ON DELETE SET NULL;


--
-- Name: exchange_requests exchange_requests_processed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exchange_requests
    ADD CONSTRAINT exchange_requests_processed_by_fkey FOREIGN KEY (processed_by) REFERENCES auth.users(id);


--
-- Name: exchange_requests exchange_requests_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.exchange_requests
    ADD CONSTRAINT exchange_requests_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: i18n_translations i18n_translations_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.i18n_translations
    ADD CONSTRAINT i18n_translations_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: items items_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.items
    ADD CONSTRAINT items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products_master(id);


--
-- Name: items items_receipt_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.items
    ADD CONSTRAINT items_receipt_id_fkey FOREIGN KEY (receipt_id) REFERENCES public.receipts(id) ON DELETE CASCADE;


--
-- Name: post_comments post_comments_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_comments
    ADD CONSTRAINT post_comments_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: post_comments post_comments_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_comments
    ADD CONSTRAINT post_comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: post_likes post_likes_post_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_likes
    ADD CONSTRAINT post_likes_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: post_likes post_likes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.post_likes
    ADD CONSTRAINT post_likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: posts posts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: price_pins price_pins_receipt_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_pins
    ADD CONSTRAINT price_pins_receipt_id_fkey FOREIGN KEY (receipt_id) REFERENCES public.receipts(id) ON DELETE CASCADE;


--
-- Name: price_pins price_pins_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_pins
    ADD CONSTRAINT price_pins_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id) ON DELETE CASCADE;


--
-- Name: price_pins price_pins_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_pins
    ADD CONSTRAINT price_pins_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id);


--
-- Name: private_store_notes private_store_notes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.private_store_notes
    ADD CONSTRAINT private_store_notes_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: product_aliases product_aliases_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_aliases
    ADD CONSTRAINT product_aliases_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products_master(id) ON DELETE CASCADE;


--
-- Name: product_aliases product_aliases_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_aliases
    ADD CONSTRAINT product_aliases_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: products_master products_master_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.products_master
    ADD CONSTRAINT products_master_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: profiles profiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: profiles profiles_referred_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_referred_by_fkey FOREIGN KEY (referred_by) REFERENCES public.profiles(id);


--
-- Name: push_subscriptions push_subscriptions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_subscriptions
    ADD CONSTRAINT push_subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: quotes quotes_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quotes
    ADD CONSTRAINT quotes_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: receipts receipts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.receipts
    ADD CONSTRAINT receipts_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: referral_rewards referral_rewards_referee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referral_rewards
    ADD CONSTRAINT referral_rewards_referee_id_fkey FOREIGN KEY (referee_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: referral_rewards referral_rewards_referrer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referral_rewards
    ADD CONSTRAINT referral_rewards_referrer_id_fkey FOREIGN KEY (referrer_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: store_bookmarks store_bookmarks_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_bookmarks
    ADD CONSTRAINT store_bookmarks_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id) ON DELETE CASCADE;


--
-- Name: store_bookmarks store_bookmarks_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_bookmarks
    ADD CONSTRAINT store_bookmarks_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: store_community_photos store_community_photos_uploaded_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_community_photos
    ADD CONSTRAINT store_community_photos_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: store_edit_requests store_edit_requests_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_edit_requests
    ADD CONSTRAINT store_edit_requests_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: store_items store_items_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_items
    ADD CONSTRAINT store_items_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: store_menu_cards store_menu_cards_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_menu_cards
    ADD CONSTRAINT store_menu_cards_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: store_menu_comments store_menu_comments_menu_card_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_menu_comments
    ADD CONSTRAINT store_menu_comments_menu_card_id_fkey FOREIGN KEY (menu_card_id) REFERENCES public.store_menu_cards(id) ON DELETE CASCADE;


--
-- Name: store_menu_comments store_menu_comments_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_menu_comments
    ADD CONSTRAINT store_menu_comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: store_menu_photos store_menu_photos_card_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_menu_photos
    ADD CONSTRAINT store_menu_photos_card_fkey FOREIGN KEY (menu_card_id) REFERENCES public.store_menu_cards(id) ON DELETE CASCADE;


--
-- Name: store_menu_photos store_menu_photos_uploaded_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_menu_photos
    ADD CONSTRAINT store_menu_photos_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: store_menu_replies store_menu_replies_comment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_menu_replies
    ADD CONSTRAINT store_menu_replies_comment_id_fkey FOREIGN KEY (comment_id) REFERENCES public.store_menu_comments(id) ON DELETE CASCADE;


--
-- Name: store_menu_replies store_menu_replies_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_menu_replies
    ADD CONSTRAINT store_menu_replies_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: store_photos store_photos_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_photos
    ADD CONSTRAINT store_photos_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: store_reactions store_reactions_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_reactions
    ADD CONSTRAINT store_reactions_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(id) ON DELETE CASCADE;


--
-- Name: store_reactions store_reactions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.store_reactions
    ADD CONSTRAINT store_reactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: announcements Admins can manage announcements; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins can manage announcements" ON public.announcements USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: receipts Admins can read all receipts; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins can read all receipts" ON public.receipts FOR SELECT USING (((user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))));


--
-- Name: receipts Admins can update all receipts; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins can update all receipts" ON public.receipts FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: profiles Admins delete profiles; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins delete profiles" ON public.profiles FOR DELETE USING ((EXISTS ( SELECT 1
   FROM public.profiles p
  WHERE ((p.id = auth.uid()) AND (p.is_admin = true)))));


--
-- Name: items Admins manage all items; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins manage all items" ON public.items USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: banned_words Admins manage banned_words; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins manage banned_words" ON public.banned_words USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: banned_users Admins manage bans; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins manage bans" ON public.banned_users USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: products_master Admins manage products; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins manage products" ON public.products_master FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: comment_reports Admins manage reports; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins manage reports" ON public.comment_reports FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: store_items Admins manage store_items; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins manage store_items" ON public.store_items USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: profiles Admins update all profiles; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins update all profiles" ON public.profiles FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM public.profiles p
  WHERE ((p.id = auth.uid()) AND (p.is_admin = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.profiles p
  WHERE ((p.id = auth.uid()) AND (p.is_admin = true)))));


--
-- Name: price_pins Admins update price_pins; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins update price_pins" ON public.price_pins FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: store_menu_cards Admins update store_menu_cards; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins update store_menu_cards" ON public.store_menu_cards FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: stores Admins update stores; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins update stores" ON public.stores FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: announcements Anyone can view active announcements; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can view active announcements" ON public.announcements FOR SELECT USING (((is_active = true) AND ((starts_at IS NULL) OR (starts_at <= now())) AND ((ends_at IS NULL) OR (ends_at >= now()))));


--
-- Name: banned_words Anyone reads active banned_words; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone reads active banned_words" ON public.banned_words FOR SELECT USING (((is_active = true) OR (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))));


--
-- Name: store_items Anyone reads active store_items; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone reads active store_items" ON public.store_items FOR SELECT USING (((is_active = true) OR (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))));


--
-- Name: product_aliases Anyone reads aliases; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone reads aliases" ON public.product_aliases FOR SELECT USING (true);


--
-- Name: products_master Anyone reads products_master; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone reads products_master" ON public.products_master FOR SELECT USING (true);


--
-- Name: product_aliases Authenticated insert aliases; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Authenticated insert aliases" ON public.product_aliases FOR INSERT WITH CHECK ((auth.uid() IS NOT NULL));


--
-- Name: products_master Authenticated insert products; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Authenticated insert products" ON public.products_master FOR INSERT WITH CHECK ((auth.uid() IS NOT NULL));


--
-- Name: profiles Authenticated users can read all profiles; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Authenticated users can read all profiles" ON public.profiles FOR SELECT TO authenticated USING (true);


--
-- Name: profiles Users can view own profile only; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view own profile only" ON public.profiles FOR SELECT TO authenticated USING ((auth.uid() = id));


--
-- Name: comment_reports Users insert own reports; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users insert own reports" ON public.comment_reports FOR INSERT WITH CHECK ((reporter_id = auth.uid()));


--
-- Name: private_store_notes Users manage own notes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users manage own notes" ON public.private_store_notes USING ((user_id = auth.uid())) WITH CHECK ((user_id = auth.uid()));


--
-- Name: banned_users Users see own ban + admins all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users see own ban + admins all" ON public.banned_users FOR SELECT USING (((user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))));


--
-- Name: comment_reports Users see own reports; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users see own reports" ON public.comment_reports FOR SELECT USING (((reporter_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))));


--
-- Name: profiles Users update own profile; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users update own profile" ON public.profiles FOR UPDATE USING ((id = auth.uid())) WITH CHECK ((id = auth.uid()));


--
-- Name: ad_missions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ad_missions ENABLE ROW LEVEL SECURITY;

--
-- Name: ad_missions ad_missions_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ad_missions_own ON public.ad_missions USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: ad_revenue; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ad_revenue ENABLE ROW LEVEL SECURITY;

--
-- Name: ad_revenue ad_revenue_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ad_revenue_admin ON public.ad_revenue USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: ad_views; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ad_views ENABLE ROW LEVEL SECURITY;

--
-- Name: ad_views ad_views_admin_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ad_views_admin_select ON public.ad_views FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: ad_views ad_views_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ad_views_insert_own ON public.ad_views FOR INSERT WITH CHECK ((user_id = auth.uid()));


--
-- Name: ad_views ad_views_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ad_views_select_own ON public.ad_views FOR SELECT USING ((user_id = auth.uid()));


--
-- Name: admin_messages; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.admin_messages ENABLE ROW LEVEL SECURITY;

--
-- Name: stores allow all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "allow all" ON public.stores USING (true) WITH CHECK (true);


--
-- Name: admin_messages am_admin_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY am_admin_all ON public.admin_messages TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: admin_messages am_user_mark_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY am_user_mark_read ON public.admin_messages FOR UPDATE TO authenticated USING ((recipient_id = auth.uid())) WITH CHECK ((recipient_id = auth.uid()));


--
-- Name: admin_messages am_user_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY am_user_select ON public.admin_messages FOR SELECT TO authenticated USING (((recipient_id = auth.uid()) AND ((expires_at IS NULL) OR (expires_at > now()))));


--
-- Name: announcements; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

--
-- Name: attendance; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;

--
-- Name: attendance attendance_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY attendance_own ON public.attendance USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: ct_posts auth_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY auth_delete ON public.ct_posts FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: ct_posts auth_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY auth_insert ON public.ct_posts FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: ct_comments auth_insert_ct_comments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY auth_insert_ct_comments ON public.ct_comments FOR INSERT TO authenticated WITH CHECK ((auth.uid() = user_id));


--
-- Name: price_pins auth_insert_price_pins; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY auth_insert_price_pins ON public.price_pins FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: stores auth_insert_stores; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY auth_insert_stores ON public.stores FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: ct_notifications auth_read_ct_notif; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY auth_read_ct_notif ON public.ct_notifications FOR SELECT TO authenticated USING ((auth.uid() = recipient_id));


--
-- Name: ct_posts auth_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY auth_update ON public.ct_posts FOR UPDATE USING ((auth.uid() = user_id));


--
-- Name: ct_notifications auth_update_ct_notif; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY auth_update_ct_notif ON public.ct_notifications FOR UPDATE TO authenticated USING ((auth.uid() = recipient_id));


--
-- Name: stores auth_update_stores; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY auth_update_stores ON public.stores FOR UPDATE TO authenticated USING (true);


--
-- Name: banned_users; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.banned_users ENABLE ROW LEVEL SECURITY;

--
-- Name: banned_words; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.banned_words ENABLE ROW LEVEL SECURITY;

--
-- Name: coin_transactions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.coin_transactions ENABLE ROW LEVEL SECURITY;

--
-- Name: coin_transactions coin_tx_admin_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY coin_tx_admin_select ON public.coin_transactions FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: coin_transactions coin_tx_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY coin_tx_select_own ON public.coin_transactions FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: comment_likes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.comment_likes ENABLE ROW LEVEL SECURITY;

--
-- Name: comment_likes comment_likes_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY comment_likes_own ON public.comment_likes USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: comment_quota_grants; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.comment_quota_grants ENABLE ROW LEVEL SECURITY;

--
-- Name: comment_reports; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.comment_reports ENABLE ROW LEVEL SECURITY;

--
-- Name: ct_comments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ct_comments ENABLE ROW LEVEL SECURITY;

--
-- Name: ct_comments ct_comments_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ct_comments_delete ON public.ct_comments FOR DELETE USING (((auth.uid() = user_id) OR (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))));


--
-- Name: ct_notices; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ct_notices ENABLE ROW LEVEL SECURITY;

--
-- Name: ct_notices ct_notices_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ct_notices_delete ON public.ct_notices FOR DELETE USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: ct_notices ct_notices_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ct_notices_insert ON public.ct_notices FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: ct_notices ct_notices_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ct_notices_select ON public.ct_notices FOR SELECT USING (((is_active = true) OR (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))));


--
-- Name: ct_notices ct_notices_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ct_notices_update ON public.ct_notices FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: ct_notifications; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ct_notifications ENABLE ROW LEVEL SECURITY;

--
-- Name: ct_post_likes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ct_post_likes ENABLE ROW LEVEL SECURITY;

--
-- Name: ct_post_likes ct_post_likes_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ct_post_likes_delete ON public.ct_post_likes FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: ct_post_likes ct_post_likes_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ct_post_likes_insert ON public.ct_post_likes FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: ct_post_likes ct_post_likes_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ct_post_likes_select ON public.ct_post_likes FOR SELECT USING (true);


--
-- Name: ct_posts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ct_posts ENABLE ROW LEVEL SECURITY;

--
-- Name: ct_posts ct_posts_admin_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ct_posts_admin_all ON public.ct_posts USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: draw_entries; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.draw_entries ENABLE ROW LEVEL SECURITY;

--
-- Name: draws; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.draws ENABLE ROW LEVEL SECURITY;

--
-- Name: draws draws_admin_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY draws_admin_write ON public.draws USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: draw_entries entries_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY entries_insert_own ON public.draw_entries FOR INSERT WITH CHECK (((auth.uid() = user_id) AND (COALESCE(is_winner, false) = false)));


--
-- Name: draw_entries entries_read_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY entries_read_own ON public.draw_entries FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: exchange_requests; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.exchange_requests ENABLE ROW LEVEL SECURITY;

--
-- Name: exchange_requests exr_admin_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY exr_admin_update ON public.exchange_requests FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: exchange_requests exr_user_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY exr_user_insert ON public.exchange_requests FOR INSERT TO authenticated WITH CHECK ((user_id = auth.uid()));


--
-- Name: exchange_requests exr_user_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY exr_user_select ON public.exchange_requests FOR SELECT TO authenticated USING (((user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))));


--
-- Name: i18n_translations i18n_admin_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY i18n_admin_write ON public.i18n_translations USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: i18n_translations i18n_select_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY i18n_select_all ON public.i18n_translations FOR SELECT USING (true);


--
-- Name: i18n_translations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.i18n_translations ENABLE ROW LEVEL SECURITY;

--
-- Name: items; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.items ENABLE ROW LEVEL SECURITY;

--
-- Name: items items 저장; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "items 저장" ON public.items FOR INSERT WITH CHECK ((receipt_id IN ( SELECT receipts.id
   FROM public.receipts
  WHERE (receipts.user_id = auth.uid()))));


--
-- Name: items items 조회; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "items 조회" ON public.items FOR SELECT USING ((receipt_id IN ( SELECT receipts.id
   FROM public.receipts
  WHERE (receipts.user_id = auth.uid()))));


--
-- Name: items items_admin_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY items_admin_delete ON public.items FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: kospa_votes kospa_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY kospa_delete ON public.kospa_votes FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: kospa_votes kospa_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY kospa_insert ON public.kospa_votes FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: kospa_votes kospa_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY kospa_select ON public.kospa_votes FOR SELECT USING (true);


--
-- Name: kospa_votes kospa_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY kospa_update ON public.kospa_votes FOR UPDATE USING ((auth.uid() = user_id));


--
-- Name: kospa_votes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.kospa_votes ENABLE ROW LEVEL SECURITY;

--
-- Name: kospa_votes kospa_votes_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY kospa_votes_delete ON public.kospa_votes FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: kospa_votes kospa_votes_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY kospa_votes_insert ON public.kospa_votes FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: kospa_votes kospa_votes_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY kospa_votes_select ON public.kospa_votes FOR SELECT USING (true);


--
-- Name: kospa_votes kospa_votes_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY kospa_votes_update ON public.kospa_votes FOR UPDATE USING ((auth.uid() = user_id));


--
-- Name: local_ads; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.local_ads ENABLE ROW LEVEL SECURITY;

--
-- Name: local_ads local_ads_admin_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY local_ads_admin_write ON public.local_ads USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: local_ads local_ads_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY local_ads_select ON public.local_ads FOR SELECT USING (((is_active = true) OR (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))));


--
-- Name: pin_ratings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.pin_ratings ENABLE ROW LEVEL SECURITY;

--
-- Name: pin_ratings pin_ratings_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pin_ratings_insert_own ON public.pin_ratings FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: pin_ratings pin_ratings_select_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pin_ratings_select_all ON public.pin_ratings FOR SELECT USING (true);


--
-- Name: pin_ratings pin_ratings_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pin_ratings_update_own ON public.pin_ratings FOR UPDATE USING ((auth.uid() = user_id));


--
-- Name: post_comments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.post_comments ENABLE ROW LEVEL SECURITY;

--
-- Name: post_likes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;

--
-- Name: post_likes post_likes_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY post_likes_own ON public.post_likes USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: posts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

--
-- Name: posts posts_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY posts_own ON public.posts USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: price_pins; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.price_pins ENABLE ROW LEVEL SECURITY;

--
-- Name: price_pins price_pins_admin_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY price_pins_admin_delete ON public.price_pins FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: price_pins price_pins_admin_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY price_pins_admin_update ON public.price_pins FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: price_pins price_pins_select_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY price_pins_select_all ON public.price_pins FOR SELECT USING (true);


--
-- Name: private_store_notes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.private_store_notes ENABLE ROW LEVEL SECURITY;

--
-- Name: product_aliases; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.product_aliases ENABLE ROW LEVEL SECURITY;

--
-- Name: products_master; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.products_master ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles profiles_insert_self; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY profiles_insert_self ON public.profiles FOR INSERT WITH CHECK ((auth.uid() = id));


--
-- Name: profiles profiles_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY profiles_update_own ON public.profiles FOR UPDATE USING ((auth.uid() = id)) WITH CHECK ((auth.uid() = id));


--
-- Name: push_subscriptions ps_user_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ps_user_delete ON public.push_subscriptions FOR DELETE TO authenticated USING (((user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))));


--
-- Name: push_subscriptions ps_user_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ps_user_select ON public.push_subscriptions FOR SELECT TO authenticated USING (((user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))));


--
-- Name: push_subscriptions ps_user_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ps_user_update ON public.push_subscriptions FOR UPDATE TO authenticated USING ((user_id = auth.uid())) WITH CHECK ((user_id = auth.uid()));


--
-- Name: push_subscriptions ps_user_upsert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ps_user_upsert ON public.push_subscriptions FOR INSERT TO authenticated WITH CHECK ((user_id = auth.uid()));


--
-- Name: ct_posts public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY public_read ON public.ct_posts FOR SELECT USING (true);


--
-- Name: ct_comments public_read_ct_comments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY public_read_ct_comments ON public.ct_comments FOR SELECT USING (true);


--
-- Name: price_pins public_read_price_pins; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY public_read_price_pins ON public.price_pins FOR SELECT TO authenticated, anon USING (true);


--
-- Name: stores public_read_stores; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY public_read_stores ON public.stores FOR SELECT TO authenticated, anon USING (true);


--
-- Name: push_subscriptions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;

--
-- Name: quotes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quotes ENABLE ROW LEVEL SECURITY;

--
-- Name: quotes quotes_admin_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY quotes_admin_write ON public.quotes USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: quotes quotes_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY quotes_select ON public.quotes FOR SELECT USING (((is_active = true) OR (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))));


--
-- Name: receipts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.receipts ENABLE ROW LEVEL SECURITY;

--
-- Name: receipts receipts_admin_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY receipts_admin_delete ON public.receipts FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: receipts receipts_admin_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY receipts_admin_update ON public.receipts FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: referral_rewards; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.referral_rewards ENABLE ROW LEVEL SECURITY;

--
-- Name: referral_rewards refrew_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY refrew_select_own ON public.referral_rewards FOR SELECT USING ((referrer_id = auth.uid()));


--
-- Name: store_community_photos scp_delete_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY scp_delete_own ON public.store_community_photos FOR DELETE USING (((auth.uid() = uploaded_by) OR (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))));


--
-- Name: store_community_photos scp_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY scp_insert ON public.store_community_photos FOR INSERT WITH CHECK ((auth.uid() = uploaded_by));


--
-- Name: store_community_photos scp_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY scp_read ON public.store_community_photos FOR SELECT USING (true);


--
-- Name: store_edit_requests ser_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ser_insert_own ON public.store_edit_requests FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: store_edit_requests ser_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ser_select ON public.store_edit_requests FOR SELECT USING (((auth.uid() = user_id) OR (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))));


--
-- Name: store_edit_requests ser_update_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ser_update_admin ON public.store_edit_requests FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: store_menu_cards smc_delete_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY smc_delete_own ON public.store_menu_cards FOR DELETE USING (((auth.uid() = created_by) OR (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))));


--
-- Name: store_menu_cards smc_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY smc_insert ON public.store_menu_cards FOR INSERT WITH CHECK ((auth.uid() = created_by));


--
-- Name: store_menu_cards smc_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY smc_read ON public.store_menu_cards FOR SELECT USING (true);


--
-- Name: store_menu_cards smc_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY smc_update_own ON public.store_menu_cards FOR UPDATE USING (((auth.uid() = created_by) OR (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))))) WITH CHECK (((auth.uid() = created_by) OR (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))));


--
-- Name: store_menu_comments smcmt_delete_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY smcmt_delete_own ON public.store_menu_comments FOR DELETE USING (((auth.uid() = user_id) OR (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))));


--
-- Name: store_menu_comments smcmt_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY smcmt_insert ON public.store_menu_comments FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: store_menu_comments smcmt_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY smcmt_read ON public.store_menu_comments FOR SELECT USING (true);


--
-- Name: store_menu_comments smcmt_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY smcmt_update ON public.store_menu_comments FOR UPDATE USING ((auth.uid() = user_id));


--
-- Name: store_menu_replies smr_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY smr_insert ON public.store_menu_replies FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: store_menu_replies smr_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY smr_read ON public.store_menu_replies FOR SELECT USING (true);


--
-- Name: store_menu_replies smrpl_delete_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY smrpl_delete_own ON public.store_menu_replies FOR DELETE USING (((auth.uid() = user_id) OR (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))));


--
-- Name: store_bookmarks; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.store_bookmarks ENABLE ROW LEVEL SECURITY;

--
-- Name: store_bookmarks store_bookmarks_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY store_bookmarks_own ON public.store_bookmarks USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: store_comments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.store_comments ENABLE ROW LEVEL SECURITY;

--
-- Name: store_comments store_comments_admin_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY store_comments_admin_delete ON public.store_comments FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: store_comments store_comments_insert_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY store_comments_insert_all ON public.store_comments FOR INSERT WITH CHECK (true);


--
-- Name: store_comments store_comments_own_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY store_comments_own_delete ON public.store_comments FOR DELETE TO authenticated USING ((user_id = auth.uid()));


--
-- Name: store_comments store_comments_own_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY store_comments_own_insert ON public.store_comments FOR INSERT TO authenticated WITH CHECK ((user_id = auth.uid()));


--
-- Name: store_comments store_comments_own_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY store_comments_own_update ON public.store_comments FOR UPDATE TO authenticated USING ((user_id = auth.uid()));


--
-- Name: store_comments store_comments_select_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY store_comments_select_all ON public.store_comments FOR SELECT USING (true);


--
-- Name: store_community_photos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.store_community_photos ENABLE ROW LEVEL SECURITY;

--
-- Name: store_edit_requests; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.store_edit_requests ENABLE ROW LEVEL SECURITY;

--
-- Name: store_items; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.store_items ENABLE ROW LEVEL SECURITY;

--
-- Name: store_menu_cards; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.store_menu_cards ENABLE ROW LEVEL SECURITY;

--
-- Name: store_menu_cards store_menu_cards_admin_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY store_menu_cards_admin_delete ON public.store_menu_cards FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: store_menu_cards store_menu_cards_admin_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY store_menu_cards_admin_insert ON public.store_menu_cards FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: store_menu_cards store_menu_cards_admin_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY store_menu_cards_admin_update ON public.store_menu_cards FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: store_menu_comments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.store_menu_comments ENABLE ROW LEVEL SECURITY;

--
-- Name: store_menu_comments store_menu_comments_admin_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY store_menu_comments_admin_delete ON public.store_menu_comments FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: store_menu_photos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.store_menu_photos ENABLE ROW LEVEL SECURITY;

--
-- Name: store_menu_photos store_menu_photos_admin_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY store_menu_photos_admin_delete ON public.store_menu_photos FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: store_menu_photos store_menu_photos_admin_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY store_menu_photos_admin_insert ON public.store_menu_photos FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: store_menu_photos store_menu_photos_admin_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY store_menu_photos_admin_update ON public.store_menu_photos FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: store_menu_photos store_menu_photos_select_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY store_menu_photos_select_all ON public.store_menu_photos FOR SELECT TO authenticated, anon USING (true);


--
-- Name: store_menu_replies; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.store_menu_replies ENABLE ROW LEVEL SECURITY;

--
-- Name: store_photos; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.store_photos ENABLE ROW LEVEL SECURITY;

--
-- Name: store_photos store_photos_admin_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY store_photos_admin_delete ON public.store_photos FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: store_photos store_photos_admin_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY store_photos_admin_insert ON public.store_photos FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: store_photos store_photos_admin_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY store_photos_admin_update ON public.store_photos FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: store_photos store_photos_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY store_photos_insert_own ON public.store_photos FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: store_photos store_photos_select_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY store_photos_select_all ON public.store_photos FOR SELECT TO authenticated, anon USING (true);


--
-- Name: store_reactions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.store_reactions ENABLE ROW LEVEL SECURITY;

--
-- Name: store_reactions store_reactions_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY store_reactions_own ON public.store_reactions USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: stores; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.stores ENABLE ROW LEVEL SECURITY;

--
-- Name: stores stores_admin_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY stores_admin_delete ON public.stores FOR DELETE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: stores stores_admin_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY stores_admin_update ON public.stores FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: stores stores_admin_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY stores_admin_write ON public.stores USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))));


--
-- Name: stores stores_select_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY stores_select_all ON public.stores FOR SELECT USING (true);


--
-- Name: receipts 본인 데이터만 삭제; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "본인 데이터만 삭제" ON public.receipts FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: receipts 본인 데이터만 수정; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "본인 데이터만 수정" ON public.receipts FOR UPDATE USING ((auth.uid() = user_id));


--
-- Name: receipts 본인 데이터만 저장; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "본인 데이터만 저장" ON public.receipts FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: receipts 본인 데이터만 조회; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "본인 데이터만 조회" ON public.receipts FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: receipts 커뮤니티 가게 조회; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "커뮤니티 가게 조회" ON public.receipts FOR SELECT USING ((auth.role() = 'authenticated'::text));


--
-- Name: items 커뮤니티 품목 조회; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "커뮤니티 품목 조회" ON public.items FOR SELECT USING ((auth.role() = 'authenticated'::text));


--
-- PostgreSQL database dump complete
--

-- (removed: \unrestrict meta-command — not needed for dev apply)

