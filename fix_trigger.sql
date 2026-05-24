-- ============================================================
-- 회원가입 "Database error saving new user" 수정
-- Supabase Dashboard → SQL Editor → 아래 전체 붙여넣기 → Run
-- ============================================================

-- STEP 1. profiles 테이블이 없으면 생성
CREATE TABLE IF NOT EXISTS profiles (
  id             UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nickname       TEXT NOT NULL DEFAULT '節約ユーザー',
  referral_code  TEXT UNIQUE,
  referred_by    UUID REFERENCES profiles(id),
  level          INT  DEFAULT 0,
  coin_balance   INT  DEFAULT 0,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- STEP 2. 기존 트리거/함수 삭제 후 재생성 (EXCEPTION 처리 추가)
DROP TRIGGER  IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user();

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  new_code TEXT;
BEGIN
  new_code := upper(substring(gen_random_uuid()::text FROM 1 FOR 8));
  INSERT INTO public.profiles (id, nickname, referral_code)
  VALUES (NEW.id, '節約ユーザー', new_code)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- 프로필 생성 실패해도 유저 가입은 계속 진행
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- STEP 3. RLS 설정 (없으면 추가)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename='profiles' AND policyname='profiles_read_all'
  ) THEN
    CREATE POLICY "profiles_read_all"  ON profiles FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename='profiles' AND policyname='profiles_write_own'
  ) THEN
    CREATE POLICY "profiles_write_own" ON profiles FOR ALL USING (auth.uid() = id);
  END IF;
END $$;

-- STEP 4. profiles INSERT는 트리거(SECURITY DEFINER)가 하므로
--         anon/authenticated 역할에도 insert 허용
GRANT INSERT ON public.profiles TO anon;
GRANT INSERT ON public.profiles TO authenticated;
GRANT ALL    ON public.profiles TO service_role;

-- 완료
SELECT 'fix_trigger.sql 적용 완료' AS result;
