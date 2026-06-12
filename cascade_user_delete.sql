-- ════════════════════════════════════════════════════════════════════════════
-- 유저 삭제 자동 정리 — auth.users / profiles 참조 FK 일괄 변환 (b465 운영)
--   목적: Supabase 대시보드에서 유저 삭제 시 "Database error deleting user"
--         (자식 데이터 FK 막힘) 없이 자동 정리되게 한다.
--
--   정책:
--     - created_by / uploaded_by / referred_by 컬럼(공유 콘텐츠·추천 관계)
--       이고 NULL 허용이면  → ON DELETE SET NULL  (메뉴카드·가게사진은 보존,
--                                                  작성자만 NULL 처리)
--     - 그 외(user_id 등 개인 데이터)            → ON DELETE CASCADE (함께 삭제)
--
--   auth.users 직접 참조 + public.profiles 참조 FK 를 모두 처리한다.
--   (user_id 가 profiles 를 참조하고, profiles.id 가 auth.users 를 참조하는
--    2단 체인까지 CASCADE 로 연결되어야 대시보드 삭제가 끝까지 전파됨)
--
--   ⚠️ FK 제약을 변경합니다. 실행 전 백업 권장. 1회 실행이면 충분(idempotent —
--      이미 CASCADE/SET NULL 인 FK 는 건너뜀).
--   Supabase SQL Editor 에서 실행.
-- ════════════════════════════════════════════════════════════════════════════

DO $$
DECLARE
  r RECORD;
  v_nullable text;
  v_action   text;
BEGIN
  FOR r IN
    SELECT tc.table_schema,
           tc.table_name,
           tc.constraint_name,
           kcu.column_name,
           ccu.table_schema AS ref_schema,
           ccu.table_name   AS ref_table
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
      ON tc.constraint_name = kcu.constraint_name
     AND tc.table_schema    = kcu.table_schema
    JOIN information_schema.constraint_column_usage ccu
      ON tc.constraint_name = ccu.constraint_name
    JOIN information_schema.referential_constraints rc
      ON tc.constraint_name = rc.constraint_name
    WHERE tc.constraint_type = 'FOREIGN KEY'
      AND (
            (ccu.table_schema = 'auth'   AND ccu.table_name = 'users')
         OR (ccu.table_schema = 'public' AND ccu.table_name = 'profiles')
          )
      AND rc.delete_rule NOT IN ('CASCADE', 'SET NULL')
  LOOP
    -- 컬럼 NULL 허용 여부
    SELECT is_nullable INTO v_nullable
    FROM information_schema.columns
    WHERE table_schema = r.table_schema
      AND table_name   = r.table_name
      AND column_name  = r.column_name;

    -- 공유 콘텐츠/추천 컬럼이고 NULL 허용이면 SET NULL, 아니면 CASCADE
    IF r.column_name IN ('created_by', 'uploaded_by', 'referred_by') AND v_nullable = 'YES' THEN
      v_action := 'SET NULL';
    ELSE
      v_action := 'CASCADE';
    END IF;

    EXECUTE format('ALTER TABLE %I.%I DROP CONSTRAINT %I',
                   r.table_schema, r.table_name, r.constraint_name);
    EXECUTE format('ALTER TABLE %I.%I ADD CONSTRAINT %I FOREIGN KEY (%I) REFERENCES %I.%I(id) ON DELETE %s',
                   r.table_schema, r.table_name, r.constraint_name,
                   r.column_name, r.ref_schema, r.ref_table, v_action);

    RAISE NOTICE 'fixed %.%.%  ->  ON DELETE %  (ref %.%)',
                 r.table_schema, r.table_name, r.column_name, v_action, r.ref_schema, r.ref_table;
  END LOOP;
  RAISE NOTICE '✅ 완료 — 이제 대시보드에서 유저 삭제가 자동 정리됩니다.';
END $$;

-- ════════════════════════════════════════════════════════════════════════════
-- 검증 — auth.users / profiles 참조 FK 의 delete_rule 확인 (전부 CASCADE/SET NULL 이어야)
--   SELECT tc.table_name, kcu.column_name, rc.delete_rule
--   FROM information_schema.table_constraints tc
--   JOIN information_schema.key_column_usage kcu
--     ON tc.constraint_name=kcu.constraint_name AND tc.table_schema=kcu.table_schema
--   JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name=ccu.constraint_name
--   JOIN information_schema.referential_constraints rc ON tc.constraint_name=rc.constraint_name
--   WHERE tc.constraint_type='FOREIGN KEY'
--     AND ((ccu.table_schema='auth' AND ccu.table_name='users')
--       OR (ccu.table_schema='public' AND ccu.table_name='profiles'))
--   ORDER BY rc.delete_rule, tc.table_name;
-- ════════════════════════════════════════════════════════════════════════════
