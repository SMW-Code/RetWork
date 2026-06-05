-- ════════════════════════════════════════════════════════════════════════════
-- store_edit_requests 에 kind 컬럼 추가
--   • 'general'  : 가게상세모달 ⋮ → 修正リクエスト (기존)
--   • 'location' : 가성비맵 가게목록 → 📍 位置修正リクエスト (신규)
--   어드민 대시보드에서 kind 로 분리 표시 ("가게 수정요청" / "위치수정 요청")
--
--   Supabase SQL Editor 에 그대로 붙여넣고 RUN. (idempotent)
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

ALTER TABLE store_edit_requests
  ADD COLUMN IF NOT EXISTS kind TEXT NOT NULL DEFAULT 'general';

CREATE INDEX IF NOT EXISTS idx_ser_kind_status_created
  ON store_edit_requests(kind, status, created_at DESC);

COMMIT;

-- 검증:  SELECT kind, status, count(*) FROM store_edit_requests GROUP BY 1,2;
