-- ════════════════════════════════════════════════════════════════════════════
-- private_store_notes v2 — 10단계 별점 도입
--
-- 변경:
--   1. rating SMALLINT (1~10) 컬럼 추가
--   2. 옛 sentiment 값 → rating 자동 변환 (한번만)
--   3. sentiment 컬럼은 NULL 허용 유지 (옛 데이터 보존, 더 이상 새로 쓰지 않음)
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- 1) rating 컬럼 추가 (이미 있으면 SKIP)
ALTER TABLE private_store_notes
  ADD COLUMN IF NOT EXISTS rating SMALLINT
  CHECK (rating IS NULL OR (rating BETWEEN 1 AND 10));

-- 2) 옛 sentiment → rating 매핑 (rating이 비어있는 행만)
--    'love'         → 10 (강추)
--    'recommend'    → 9
--    'neutral'      → 5
--    'disappointing'→ 3
--    'avoid'        → 1
UPDATE private_store_notes
SET rating = CASE sentiment
  WHEN 'love'          THEN 10
  WHEN 'recommend'     THEN 9
  WHEN 'great'         THEN 9   -- 별칭 (예전 SENTIMENT_OPTS에 'great' 존재했을 가능성)
  WHEN 'neutral'       THEN 5
  WHEN 'disappointing' THEN 3
  WHEN 'avoid'         THEN 1
  ELSE NULL
END
WHERE rating IS NULL AND sentiment IS NOT NULL;

-- 3) updated_at 자동 갱신 트리거 (없으면 추가)
CREATE OR REPLACE FUNCTION psn_touch_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS psn_touch_updated_at_trg ON private_store_notes;
CREATE TRIGGER psn_touch_updated_at_trg
  BEFORE UPDATE ON private_store_notes
  FOR EACH ROW
  EXECUTE FUNCTION psn_touch_updated_at();

COMMIT;

-- 검증
-- SELECT rating, sentiment, COUNT(*) FROM private_store_notes GROUP BY rating, sentiment ORDER BY rating;
