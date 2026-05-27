-- ════════════════════════════════════════════════════════════════════════════
-- 보안 패치 v1 — 권한 상승 / 코인 위변조 / 셀프 당첨 / 메뉴 변조 차단
-- 적용처: Supabase SQL Editor (또는 supabase db push)
-- 적용 전 백업 권장: supabase db dump --schema-only > backup_$(date).sql
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ─── [1] profiles: 권한 상승 (is_admin / coin_balance 위변조) 방지 ───────────
-- 기존 정책 (FOR ALL USING auth.uid()=id) 은 WITH CHECK 가 없어
-- 클라이언트가 update({is_admin:true, coin_balance:99999999}) 가능했음.

DROP POLICY IF EXISTS profiles_write_own ON profiles;
DROP POLICY IF EXISTS "Users insert own profile" ON profiles;
DROP POLICY IF EXISTS profiles_update_own ON profiles;
DROP POLICY IF EXISTS profiles_insert_self ON profiles;

-- INSERT: 본인 id 로만 가입 가능 (트리거가 만들지만 client 도 fallback 가능)
CREATE POLICY profiles_insert_self ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- UPDATE: 본인 행만, 그리고 본인 id 로 유지해야 함
CREATE POLICY profiles_update_own ON profiles
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- 권한 상승 / 코인 인플레 방지 트리거
-- (UPDATE 시 is_admin 와 coin_balance 가 변경되면 service_role 이 아닌 한 차단)
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
      USING ERRCODE = '42501'; -- insufficient_privilege
  END IF;

  IF NEW.coin_balance IS DISTINCT FROM OLD.coin_balance THEN
    RAISE EXCEPTION 'profiles.coin_balance cannot be changed by client (use add_coins function)'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_block_privileged_columns_trg ON profiles;
CREATE TRIGGER profiles_block_privileged_columns_trg
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION profiles_block_privileged_columns();

-- ─── [2] coin_transactions: 클라이언트 INSERT 차단 ──────────────────────────
-- FOR ALL USING (auth.uid()=user_id) 는 INSERT 도 허용 → 임의 코인 적립 가능했음.

DROP POLICY IF EXISTS coins_own ON coin_transactions;
DROP POLICY IF EXISTS coin_tx_insert_own ON coin_transactions;
DROP POLICY IF EXISTS coin_tx_select_own ON coin_transactions;
DROP POLICY IF EXISTS coin_tx_admin_select ON coin_transactions;

-- SELECT: 본인 거래만 조회
CREATE POLICY coin_tx_select_own ON coin_transactions
  FOR SELECT
  USING (auth.uid() = user_id);

-- SELECT: 어드민 전체 조회 (대시보드)
CREATE POLICY coin_tx_admin_select ON coin_transactions
  FOR SELECT
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true));

-- INSERT/UPDATE/DELETE: 일반 클라이언트 차단 (SECURITY DEFINER 함수만 사용)
REVOKE INSERT, UPDATE, DELETE ON coin_transactions FROM anon, authenticated;

-- ─── [3] add_coins(): 권한 강화 + search_path 설정 ─────────────────────────
-- 기존 함수가 SECURITY DEFINER 인데 search_path 미설정 + EXECUTE 권한 광범위.

REVOKE EXECUTE ON FUNCTION add_coins(UUID, INTEGER, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION add_coins(UUID, INTEGER, TEXT, TEXT) TO service_role;

-- 함수 재정의 (search_path 명시 + 호출자가 본인 user_id 만 적립하도록)
CREATE OR REPLACE FUNCTION add_coins(
  p_user_id UUID,
  p_amount INTEGER,
  p_type TEXT,
  p_description TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- service_role 은 자유롭게, 그 외엔 본인만
  IF current_setting('request.jwt.claims', true)::jsonb->>'role' <> 'service_role'
     AND p_user_id <> auth.uid() THEN
    RAISE EXCEPTION 'add_coins: cannot add coins to another user';
  END IF;

  -- 코인 거래 기록 + 잔액 갱신
  INSERT INTO coin_transactions(user_id, amount, type, description)
  VALUES (p_user_id, p_amount, p_type, p_description);

  UPDATE profiles
     SET coin_balance = coin_balance + p_amount
   WHERE id = p_user_id;
END;
$$;

-- ─── [4] draw_entries: is_winner 셀프 설정 + 임의 entry 생성 차단 ───────────

DROP POLICY IF EXISTS entries_own ON draw_entries;
DROP POLICY IF EXISTS entries_read_own ON draw_entries;
DROP POLICY IF EXISTS entries_insert_own ON draw_entries;

-- SELECT: 본인 응모 조회
CREATE POLICY entries_read_own ON draw_entries
  FOR SELECT
  USING (auth.uid() = user_id);

-- INSERT: 본인 응모, is_winner=false 강제 (당첨은 어드민/서버 함수에서만)
CREATE POLICY entries_insert_own ON draw_entries
  FOR INSERT
  WITH CHECK (auth.uid() = user_id AND COALESCE(is_winner, false) = false);

-- UPDATE/DELETE: 클라이언트 차단 (어드민/서버 함수만)
REVOKE UPDATE, DELETE ON draw_entries FROM anon, authenticated;

-- ─── [5] store_menu_cards: 모든 메뉴 변조 차단 ──────────────────────────────

DROP POLICY IF EXISTS smc_update ON store_menu_cards;
DROP POLICY IF EXISTS smc_update_own ON store_menu_cards;

CREATE POLICY smc_update_own ON store_menu_cards
  FOR UPDATE
  USING (
    auth.uid() = created_by
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
  )
  WITH CHECK (
    auth.uid() = created_by
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
  );

-- DELETE: 본인 또는 어드민
DROP POLICY IF EXISTS smc_delete_own ON store_menu_cards;
CREATE POLICY smc_delete_own ON store_menu_cards
  FOR DELETE
  USING (
    auth.uid() = created_by
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
  );

-- ─── [6] store_menu_comments / store_menu_replies / store_community_photos
--      DELETE 정책 추가 (본인 또는 어드민) ────────────────────────────────────

DROP POLICY IF EXISTS smcmt_delete_own ON store_menu_comments;
CREATE POLICY smcmt_delete_own ON store_menu_comments
  FOR DELETE
  USING (
    auth.uid() = user_id
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
  );

DROP POLICY IF EXISTS smrpl_delete_own ON store_menu_replies;
CREATE POLICY smrpl_delete_own ON store_menu_replies
  FOR DELETE
  USING (
    auth.uid() = user_id
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
  );

DROP POLICY IF EXISTS scp_delete_own ON store_community_photos;
CREATE POLICY scp_delete_own ON store_community_photos
  FOR DELETE
  USING (
    auth.uid() = uploaded_by
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
  );

-- ─── [7] WITH CHECK 누락 정책들 일괄 보강 ───────────────────────────────────
-- 본인 user_id 만 INSERT/UPDATE 가능하도록 강제

DROP POLICY IF EXISTS reactions_own ON store_reactions;
CREATE POLICY reactions_own ON store_reactions
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS post_likes_own ON post_likes;
CREATE POLICY post_likes_own ON post_likes
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS comment_likes_own ON comment_likes;
CREATE POLICY comment_likes_own ON comment_likes
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS bookmarks_own ON store_bookmarks;
CREATE POLICY bookmarks_own ON store_bookmarks
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS attendance_own ON attendance;
CREATE POLICY attendance_own ON attendance
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS ad_missions_own ON ad_missions;
CREATE POLICY ad_missions_own ON ad_missions
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS posts_own ON posts;
CREATE POLICY posts_own ON posts
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS comments_own ON comments;
CREATE POLICY comments_own ON comments
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ─── [8] stores: 어드민 전용 UPDATE/DELETE 정책 명시 ────────────────────────
-- 코드에서 가게 수정 기능이 있는데 정책이 없어서 service_role 키 노출 가능성 의심.

DROP POLICY IF EXISTS stores_admin_write ON stores;
CREATE POLICY stores_admin_write ON stores
  FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true));

-- ─── [9] draws: 어드민 전용 ─────────────────────────────────────────────────

DROP POLICY IF EXISTS draws_admin_write ON draws;
CREATE POLICY draws_admin_write ON draws
  FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true));

-- ─── [10] handle_new_user(): search_path 보강 ─────────────────────────────

-- 기존 함수 정의 그대로 유지하되 search_path 만 추가 (정의 본문은 fix_trigger.sql 참조)
-- ALTER FUNCTION handle_new_user() SET search_path = public, pg_temp;
-- ↑ 실제 적용 시 fix_trigger.sql 의 함수 정의 끝에 SET 절 추가 권장.
-- 이미 동일 함수가 있다면 다음 줄로 처리:
ALTER FUNCTION handle_new_user() SET search_path = public, pg_temp;

-- ─── [11] storage.objects 의 store-photos 폴더 검증 ─────────────────────────
-- 기존 정책이 임의 경로 업로드 허용 → 본인 폴더로 제한

DROP POLICY IF EXISTS store_photos_upload ON storage.objects;
CREATE POLICY store_photos_upload ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'store-photos'
    AND auth.uid() IS NOT NULL
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

COMMIT;

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
