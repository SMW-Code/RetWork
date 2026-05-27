-- ════════════════════════════════════════════════════════════════════════════
-- 보안 패치 v1 — 권한 상승 / 코인 위변조 / 셀프 당첨 / 메뉴 변조 차단
-- 적용처: Supabase SQL Editor (또는 supabase db push)
--
-- 모든 단계가 "테이블/함수 존재 시에만" 실행되도록 가드됨 → 누락 테이블 있어도 안전.
-- ════════════════════════════════════════════════════════════════════════════

-- 헬퍼: 테이블 존재 여부
CREATE OR REPLACE FUNCTION _sec_table_exists(t TEXT) RETURNS BOOLEAN
LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = t
  );
$$;

-- 헬퍼: 함수 존재 여부
CREATE OR REPLACE FUNCTION _sec_function_exists(fn TEXT) RETURNS BOOLEAN
LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = fn
  );
$$;

-- ─── [1] profiles: 권한 상승 (is_admin / coin_balance 위변조) 방지 ───────────
DO $$
BEGIN
  IF _sec_table_exists('profiles') THEN
    EXECUTE 'DROP POLICY IF EXISTS profiles_write_own ON profiles';
    EXECUTE 'DROP POLICY IF EXISTS "Users insert own profile" ON profiles';
    EXECUTE 'DROP POLICY IF EXISTS profiles_update_own ON profiles';
    EXECUTE 'DROP POLICY IF EXISTS profiles_insert_self ON profiles';

    EXECUTE 'CREATE POLICY profiles_insert_self ON profiles
             FOR INSERT WITH CHECK (auth.uid() = id)';

    EXECUTE 'CREATE POLICY profiles_update_own ON profiles
             FOR UPDATE
             USING (auth.uid() = id)
             WITH CHECK (auth.uid() = id)';
  END IF;
END $$;

-- 권한 상승 / 코인 인플레 방지 트리거
CREATE OR REPLACE FUNCTION profiles_block_privileged_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- service_role 은 통과 (어드민 백엔드 작업)
  IF current_setting('request.jwt.claims', true)::jsonb->>'role' = 'service_role' THEN
    RETURN NEW;
  END IF;

  IF NEW.is_admin IS DISTINCT FROM OLD.is_admin THEN
    RAISE EXCEPTION 'profiles.is_admin cannot be changed by client'
      USING ERRCODE = '42501';
  END IF;

  IF NEW.coin_balance IS DISTINCT FROM OLD.coin_balance THEN
    RAISE EXCEPTION 'profiles.coin_balance cannot be changed by client (use add_coins function)'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

DO $$
BEGIN
  IF _sec_table_exists('profiles') THEN
    EXECUTE 'DROP TRIGGER IF EXISTS profiles_block_privileged_columns_trg ON profiles';
    EXECUTE 'CREATE TRIGGER profiles_block_privileged_columns_trg
             BEFORE UPDATE ON profiles
             FOR EACH ROW
             EXECUTE FUNCTION profiles_block_privileged_columns()';
  END IF;
END $$;

-- ─── [2] coin_transactions: 클라이언트 INSERT 차단 ──────────────────────────
DO $$
BEGIN
  IF _sec_table_exists('coin_transactions') THEN
    EXECUTE 'DROP POLICY IF EXISTS coins_own ON coin_transactions';
    EXECUTE 'DROP POLICY IF EXISTS coin_tx_insert_own ON coin_transactions';
    EXECUTE 'DROP POLICY IF EXISTS coin_tx_select_own ON coin_transactions';
    EXECUTE 'DROP POLICY IF EXISTS coin_tx_admin_select ON coin_transactions';

    EXECUTE 'CREATE POLICY coin_tx_select_own ON coin_transactions
             FOR SELECT
             USING (auth.uid() = user_id)';

    EXECUTE 'CREATE POLICY coin_tx_admin_select ON coin_transactions
             FOR SELECT
             USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true))';

    EXECUTE 'REVOKE INSERT, UPDATE, DELETE ON coin_transactions FROM anon, authenticated';
  END IF;
END $$;

-- ─── [3] add_coins(): 권한 강화 + search_path 설정 ─────────────────────────
DO $$
BEGIN
  IF _sec_function_exists('add_coins') THEN
    EXECUTE 'DROP FUNCTION IF EXISTS add_coins(UUID, INTEGER, TEXT, TEXT)';
  END IF;
END $$;

CREATE FUNCTION add_coins(
  p_user_id UUID,
  p_amount INTEGER,
  p_type TEXT,
  p_desc TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
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

REVOKE EXECUTE ON FUNCTION add_coins(UUID, INTEGER, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION add_coins(UUID, INTEGER, TEXT, TEXT) TO service_role;

-- ─── [4] draw_entries: is_winner 셀프 설정 + 임의 entry 생성 차단 ───────────
DO $$
BEGIN
  IF _sec_table_exists('draw_entries') THEN
    EXECUTE 'DROP POLICY IF EXISTS entries_own ON draw_entries';
    EXECUTE 'DROP POLICY IF EXISTS entries_read_own ON draw_entries';
    EXECUTE 'DROP POLICY IF EXISTS entries_insert_own ON draw_entries';

    EXECUTE 'CREATE POLICY entries_read_own ON draw_entries
             FOR SELECT USING (auth.uid() = user_id)';

    EXECUTE 'CREATE POLICY entries_insert_own ON draw_entries
             FOR INSERT WITH CHECK (auth.uid() = user_id AND COALESCE(is_winner, false) = false)';

    EXECUTE 'REVOKE UPDATE, DELETE ON draw_entries FROM anon, authenticated';
  END IF;
END $$;

-- ─── [5] store_menu_cards: 모든 메뉴 변조 차단 ──────────────────────────────
DO $$
BEGIN
  IF _sec_table_exists('store_menu_cards') THEN
    EXECUTE 'DROP POLICY IF EXISTS smc_update ON store_menu_cards';
    EXECUTE 'DROP POLICY IF EXISTS smc_update_own ON store_menu_cards';
    EXECUTE 'DROP POLICY IF EXISTS smc_delete_own ON store_menu_cards';

    EXECUTE 'CREATE POLICY smc_update_own ON store_menu_cards
             FOR UPDATE
             USING (
               auth.uid() = created_by
               OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
             )
             WITH CHECK (
               auth.uid() = created_by
               OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
             )';

    EXECUTE 'CREATE POLICY smc_delete_own ON store_menu_cards
             FOR DELETE
             USING (
               auth.uid() = created_by
               OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
             )';
  END IF;
END $$;

-- ─── [6] DELETE 정책 추가 (본인 또는 어드민) ────────────────────────────────
DO $$
BEGIN
  IF _sec_table_exists('store_menu_comments') THEN
    EXECUTE 'DROP POLICY IF EXISTS smcmt_delete_own ON store_menu_comments';
    EXECUTE 'CREATE POLICY smcmt_delete_own ON store_menu_comments
             FOR DELETE
             USING (
               auth.uid() = user_id
               OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
             )';
  END IF;

  IF _sec_table_exists('store_menu_replies') THEN
    EXECUTE 'DROP POLICY IF EXISTS smrpl_delete_own ON store_menu_replies';
    EXECUTE 'CREATE POLICY smrpl_delete_own ON store_menu_replies
             FOR DELETE
             USING (
               auth.uid() = user_id
               OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
             )';
  END IF;

  IF _sec_table_exists('store_community_photos') THEN
    EXECUTE 'DROP POLICY IF EXISTS scp_delete_own ON store_community_photos';
    EXECUTE 'CREATE POLICY scp_delete_own ON store_community_photos
             FOR DELETE
             USING (
               auth.uid() = uploaded_by
               OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
             )';
  END IF;
END $$;

-- ─── [7] WITH CHECK 누락 정책들 일괄 보강 ───────────────────────────────────
DO $$
DECLARE
  tbl TEXT;
  policy_name TEXT;
  tables_with_user_id TEXT[] := ARRAY[
    'store_reactions',
    'post_likes',
    'comment_likes',
    'store_bookmarks',
    'attendance',
    'ad_missions',
    'posts',
    'comments'
  ];
BEGIN
  FOREACH tbl IN ARRAY tables_with_user_id LOOP
    IF _sec_table_exists(tbl) THEN
      -- 기존 _own 정책 이름 추정 (관례: <prefix>_own)
      -- 일괄 DROP — 동일 이름의 옛 정책이 있으면 제거
      EXECUTE format(
        'DROP POLICY IF EXISTS %I ON %I',
        replace(tbl, '_', '') || '_own',
        tbl
      );
      EXECUTE format(
        'DROP POLICY IF EXISTS %I_own ON %I',
        regexp_replace(tbl, '_[a-z]+$', ''),  -- e.g. store_reactions -> reactions
        tbl
      );
      EXECUTE format('DROP POLICY IF EXISTS %I_own ON %I', tbl, tbl);
      -- 새 정책 — FOR ALL + USING + WITH CHECK
      EXECUTE format(
        'CREATE POLICY %I_own ON %I
         FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id)',
        tbl, tbl
      );
    END IF;
  END LOOP;
END $$;

-- ─── [8] stores: 어드민 전용 정책 명시 ─────────────────────────────────────
DO $$
BEGIN
  IF _sec_table_exists('stores') THEN
    EXECUTE 'DROP POLICY IF EXISTS stores_admin_write ON stores';
    EXECUTE 'CREATE POLICY stores_admin_write ON stores
             FOR ALL
             USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true))
             WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true))';
  END IF;
END $$;

-- ─── [9] draws: 어드민 전용 ─────────────────────────────────────────────────
DO $$
BEGIN
  IF _sec_table_exists('draws') THEN
    EXECUTE 'DROP POLICY IF EXISTS draws_admin_write ON draws';
    EXECUTE 'CREATE POLICY draws_admin_write ON draws
             FOR ALL
             USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true))
             WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true))';
  END IF;
END $$;

-- ─── [10] handle_new_user(): search_path 보강 ─────────────────────────────
DO $$
BEGIN
  IF _sec_function_exists('handle_new_user') THEN
    EXECUTE 'ALTER FUNCTION handle_new_user() SET search_path = public, pg_temp';
  END IF;
END $$;

-- ─── [11] storage.objects 의 store-photos 폴더 검증 ─────────────────────────
DO $$
BEGIN
  -- storage 스키마 정책은 supabase 기본으로 존재
  EXECUTE 'DROP POLICY IF EXISTS store_photos_upload ON storage.objects';
  EXECUTE 'CREATE POLICY store_photos_upload ON storage.objects
           FOR INSERT
           WITH CHECK (
             bucket_id = ''store-photos''
             AND auth.uid() IS NOT NULL
             AND (storage.foldername(name))[1] = auth.uid()::text
           )';
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'storage.objects 정책 적용 실패 (무시): %', SQLERRM;
END $$;

-- ─── 헬퍼 함수 정리 ────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS _sec_table_exists(TEXT);
DROP FUNCTION IF EXISTS _sec_function_exists(TEXT);

-- ════════════════════════════════════════════════════════════════════════════
-- 검증 쿼리 (적용 후 실행)
-- ════════════════════════════════════════════════════════════════════════════

-- 1) 모든 RLS 정책 목록 확인
-- SELECT schemaname, tablename, policyname, cmd, qual, with_check
-- FROM pg_policies WHERE schemaname = 'public' ORDER BY tablename, policyname;

-- 2) 본인 행에서 is_admin 변경 시도 (실패해야 정상)
-- UPDATE profiles SET is_admin = true WHERE id = auth.uid();
-- → 에러: profiles.is_admin cannot be changed by client

-- 3) coin_transactions 임의 INSERT 시도 (실패해야 정상)
-- INSERT INTO coin_transactions(user_id, amount, type) VALUES (auth.uid(), 99999, 'hack');
-- → 에러: permission denied (REVOKE 효과)
