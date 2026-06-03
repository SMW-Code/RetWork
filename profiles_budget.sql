-- ════════════════════════════════════════════════════════════════════════════
-- 이달 예산 클라우드 동기화 (build 322)
--
--   profiles 테이블에 budget_amount + budget_month 컬럼 추가.
--   클라이언트가 예산 설정 시 양쪽(localStorage + Supabase) 모두 저장.
--   로그인 시 Supabase 의 budget_month 가 현재 월과 같으면 복원,
--   다르면 (새 달) 자동 리셋.
--
--   Supabase SQL Editor 에서 실행 (idempotent).
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS budget_amount INT,
  ADD COLUMN IF NOT EXISTS budget_month  TEXT;   -- 'YYYY-MM' 포맷

-- 기존 RLS 정책으로 본인 UPDATE 가능 (별도 정책 불필요)
-- 단, profiles UPDATE 시 admin_action trigger 우회 필요한 경우 client_update_profile RPC 사용

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
-- 검증
--   SELECT id, budget_amount, budget_month FROM profiles WHERE id = auth.uid();
--
-- 매달 1일 리셋:
--   클라이언트 측에서 매 로그인/홈 렌더 시 budget_month 비교 → 다르면 0 (미설정)
--   서버 측 자동 클리어는 불필요 (보존하되 클라가 표시만 안 함)
-- ════════════════════════════════════════════════════════════════════════════
