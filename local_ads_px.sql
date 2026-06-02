-- ════════════════════════════════════════════════════════════════════════════
-- 로컬 광고 크기 컬럼 확장 — 픽셀(px) 단위도 지원
--
--   기존: width_pct (가로 %) / aspect_pct (세로/가로 비율 %)
--   추가: width_px / height_px (절대 픽셀 값)
--
--   클라이언트 표시 우선순위:
--     1. width_px / height_px 가 있으면 px 사용
--     2. 없으면 width_pct / aspect_pct (%) 사용
--     3. 둘 다 없으면 width:100%, height:auto
--
--   Supabase SQL Editor 에 그대로 붙여넣고 RUN (idempotent).
-- ════════════════════════════════════════════════════════════════════════════

ALTER TABLE local_ads
  ADD COLUMN IF NOT EXISTS width_px  INT,
  ADD COLUMN IF NOT EXISTS height_px INT;

-- 검증
--   SELECT id, width_pct, aspect_pct, width_px, height_px FROM local_ads LIMIT 5;
