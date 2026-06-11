-- ════════════════════════════════════════════════════════════════════════════
-- 치리츠모 드로우(추첨) 관리 — 어드민 CRUD 지원
--   - draws 테이블에 sort_order / description 컬럼 추가 (슬라이드 순서 + 카드 설명)
--   - 어드민 INSERT/UPDATE/DELETE RLS 정책 (is_admin 게이트)
--   - SELECT 는 기존 draws_read_all 정책으로 전체 허용 (없으면 같이 생성)
--   Supabase SQL Editor 에서 실행 (idempotent).
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- 1) 컬럼 추가
ALTER TABLE draws ADD COLUMN IF NOT EXISTS sort_order  INT  DEFAULT 0;
ALTER TABLE draws ADD COLUMN IF NOT EXISTS description TEXT;

-- 2) RLS 활성화 (이미 켜져 있으면 무시)
ALTER TABLE draws ENABLE ROW LEVEL SECURITY;

-- 3) SELECT 전체 허용 (없으면 생성)
DROP POLICY IF EXISTS draws_read_all ON draws;
CREATE POLICY draws_read_all ON draws FOR SELECT USING (true);

-- 4) 어드민 INSERT
DROP POLICY IF EXISTS draws_admin_insert ON draws;
CREATE POLICY draws_admin_insert ON draws FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE));

-- 5) 어드민 UPDATE
DROP POLICY IF EXISTS draws_admin_update ON draws;
CREATE POLICY draws_admin_update ON draws FOR UPDATE
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE));

-- 6) 어드민 DELETE
DROP POLICY IF EXISTS draws_admin_delete ON draws;
CREATE POLICY draws_admin_delete ON draws FOR DELETE
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE));

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
-- 검증
--   SELECT id, title, sort_order, is_active FROM draws ORDER BY sort_order;
-- ════════════════════════════════════════════════════════════════════════════
