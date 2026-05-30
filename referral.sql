-- ════════════════════════════════════════════════════════════════════════════
-- 추천(레퍼럴) 시스템
--   • profiles.referral_code  : 사용자 고유 추천 코드 (자동 생성, UNIQUE)
--   • profiles.referred_by    : 이 유저를 추천한 사람의 UUID (1회만 설정)
--   • redeem_referral(p_code) : 추천 코드로 redeem → 추천인에게 +200 치리 (1회/유저)
--
-- Supabase SQL Editor 에 그대로 붙여넣고 RUN.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- 컬럼 추가 (이미 있어도 안전)
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS referral_code TEXT,
  ADD COLUMN IF NOT EXISTS referred_by   UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- referral_code UNIQUE 제약 (이미 있어도 안전)
-- duplicate_object(컬럼/타입 등) + duplicate_table(인덱스/제약 객체) 양쪽 다 캐치
DO $$ BEGIN
  ALTER TABLE profiles ADD CONSTRAINT profiles_referral_code_key UNIQUE (referral_code);
EXCEPTION
  WHEN duplicate_object THEN NULL;
  WHEN duplicate_table  THEN NULL;
  WHEN others           THEN RAISE NOTICE 'UNIQUE constraint skip: %', SQLERRM;
END $$;

-- 조회 인덱스
CREATE INDEX IF NOT EXISTS idx_profiles_referral_code ON profiles(referral_code) WHERE referral_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_profiles_referred_by   ON profiles(referred_by)   WHERE referred_by   IS NOT NULL;

-- 코드 없는 기존 행에 자동 부여
UPDATE profiles
SET referral_code = upper(substr(md5(random()::text || id::text), 1, 8))
WHERE referral_code IS NULL;

-- 신규 가입 시 자동 코드 부여 트리거 (profiles INSERT 시)
CREATE OR REPLACE FUNCTION profiles_set_referral_code()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.referral_code IS NULL THEN
    NEW.referral_code := upper(substr(md5(random()::text || NEW.id::text), 1, 8));
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS profiles_set_referral_code_trg ON profiles;
CREATE TRIGGER profiles_set_referral_code_trg BEFORE INSERT ON profiles
  FOR EACH ROW EXECUTE FUNCTION profiles_set_referral_code();

-- 추천 코드 redeem RPC — 추천인에게 +200 치리, 1회만
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

  -- 이미 추천인이 설정되어 있으면 무시 (유저당 1회만 적용)
  SELECT referred_by INTO v_existing FROM profiles WHERE id = v_new_user;
  IF v_existing IS NOT NULL THEN
    RETURN json_build_object('ok', false, 'err', 'already_redeemed');
  END IF;

  -- 추천 코드로 추천인 찾기
  SELECT id INTO v_referrer FROM profiles WHERE upper(referral_code) = upper(p_code) LIMIT 1;
  IF v_referrer IS NULL THEN
    RETURN json_build_object('ok', false, 'err', 'code_not_found');
  END IF;
  IF v_referrer = v_new_user THEN
    RETURN json_build_object('ok', false, 'err', 'self_referral');
  END IF;

  -- 추천 관계 기록
  UPDATE profiles SET referred_by = v_referrer WHERE id = v_new_user;

  -- 추천인에게 +200 치리 (profiles.coins 직접 증가)
  UPDATE profiles SET coins = COALESCE(coins, 0) + 200 WHERE id = v_referrer;

  -- coin_transactions 이력 기록 (테이블이 존재할 경우만)
  BEGIN
    INSERT INTO coin_transactions(user_id, amount, kind, note)
      VALUES (v_referrer, 200, 'referral', '추천 가입 보상');
  EXCEPTION WHEN undefined_table THEN NULL;
           WHEN undefined_column THEN NULL;
  END;

  RETURN json_build_object('ok', true, 'referrer', v_referrer, 'amount', 200);
END $$;

GRANT EXECUTE ON FUNCTION redeem_referral(TEXT) TO authenticated;

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
-- 검증
--   SELECT id, nickname, referral_code, referred_by FROM profiles LIMIT 5;
--   SELECT redeem_referral('ABCD1234');  -- 본인 세션에서 테스트
-- ════════════════════════════════════════════════════════════════════════════
