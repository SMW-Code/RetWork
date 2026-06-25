-- ════════════════════════════════════════════════════════════════════════════
-- price_pins 중복 방지 — 기존 중복 정리 + 유니크 인덱스 + 본인 UPDATE 정책
--
-- 문제: price_pins 에 유니크 제약이 없어 같은 유저가 같은 (가게+메뉴) 를 여러 번
--       등록하면 중복 행이 쌓여 평균가/리포트 카운트가 왜곡됨.
-- 해결: (store_id, user_id, item_name) 유니크 → 같은 유저는 1핀, 클라는 upsert 로
--       재등록 시 가격만 갱신.
--
-- Supabase SQL Editor 에 그대로 붙여넣고 RUN. (IF NOT EXISTS / DROP-CREATE → 재실행 안전)
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- 1) 기존 중복 정리 — 같은 (store_id, user_id, item_name) 그룹에서 최신 1개만 남김
DELETE FROM price_pins
WHERE id IN (
  SELECT id FROM (
    SELECT id,
           ROW_NUMBER() OVER (
             PARTITION BY store_id, user_id, item_name
             ORDER BY created_at DESC, id DESC      -- 최신(동시각이면 큰 id) 보존
           ) AS rn
    FROM price_pins
    WHERE user_id IS NOT NULL AND item_name IS NOT NULL
  ) t
  WHERE t.rn > 1
);

-- 2) 유니크 인덱스 — 같은 유저는 가게+메뉴당 1핀 (NULL 은 기본 distinct → 익명/구핀 영향 X)
CREATE UNIQUE INDEX IF NOT EXISTS price_pins_uniq_user_item
  ON price_pins (store_id, user_id, item_name);

-- 3) 본인 핀 UPDATE 허용 — upsert 의 갱신(ON CONFLICT DO UPDATE) 경로용
--    (기존엔 유저 UPDATE 정책이 없어 upsert 갱신이 RLS 에 막힘)
DROP POLICY IF EXISTS "pins_update_own" ON price_pins;
CREATE POLICY "pins_update_own" ON price_pins
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
-- 검증:
--   -- 남은 중복이 없어야 함 (0행)
--   SELECT store_id, user_id, item_name, COUNT(*)
--     FROM price_pins
--     WHERE user_id IS NOT NULL AND item_name IS NOT NULL
--     GROUP BY 1,2,3 HAVING COUNT(*) > 1;
--   -- 인덱스 존재 확인
--   SELECT indexname FROM pg_indexes WHERE tablename='price_pins';
-- ════════════════════════════════════════════════════════════════════════════
