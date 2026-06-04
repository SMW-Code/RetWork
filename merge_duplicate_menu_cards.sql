-- ════════════════════════════════════════════════════════════════════════════
-- 中華そば醤油 중복 메뉴 카드 통합 (一回限定)
--
-- 살려둘 카드: 7226cceb-d234-429b-bd4b-0fc60735bb3b
--   (is_featured=true, has_thumb=true, comments=2 — 가장 정보 풍부)
-- 삭제할 카드:
--   f13fb701-85b4-4513-ae34-3424e2f7d64b (comments=1)
--   5fe5cda9-2d94-4c56-a035-db346e8f293e (has_thumb=true, comments=2)
--
-- 데이터 손실 방지를 위해 댓글 + 사진을 살려둘 카드로 이동 후 삭제.
--
-- Supabase SQL Editor 에서 실행.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- 1) 5fe5 의 image_url 을 store_menu_photos 에 추가 (살려둘 카드로)
--    (살려둘 카드 7226 의 image_url 은 이미 있으므로 추가 사진으로 보존)
INSERT INTO store_menu_photos (menu_card_id, image_url, is_primary, sort_order, uploaded_by)
SELECT '7226cceb-d234-429b-bd4b-0fc60735bb3b'::uuid,
       image_url, FALSE, NULL, NULL
FROM store_menu_cards
WHERE id = '5fe5cda9-2d94-4c56-a035-db346e8f293e'::uuid
  AND image_url IS NOT NULL;

-- 2) 댓글 이동 (f13f + 5fe5 → 7226)
UPDATE store_menu_comments
SET menu_card_id = '7226cceb-d234-429b-bd4b-0fc60735bb3b'::uuid
WHERE menu_card_id IN (
  'f13fb701-85b4-4513-ae34-3424e2f7d64b'::uuid,
  '5fe5cda9-2d94-4c56-a035-db346e8f293e'::uuid
);

-- 3) (만약 있다면) store_menu_photos 도 이동
UPDATE store_menu_photos
SET menu_card_id = '7226cceb-d234-429b-bd4b-0fc60735bb3b'::uuid
WHERE menu_card_id IN (
  'f13fb701-85b4-4513-ae34-3424e2f7d64b'::uuid,
  '5fe5cda9-2d94-4c56-a035-db346e8f293e'::uuid
);

-- 4) 중복 카드 2개 삭제
DELETE FROM store_menu_cards
WHERE id IN (
  'f13fb701-85b4-4513-ae34-3424e2f7d64b'::uuid,
  '5fe5cda9-2d94-4c56-a035-db346e8f293e'::uuid
);

-- 5) 살려둔 카드의 평점 재계산
UPDATE store_menu_cards
SET rating_count = (
      SELECT COUNT(*) FROM store_menu_comments
      WHERE menu_card_id = '7226cceb-d234-429b-bd4b-0fc60735bb3b'::uuid
    ),
    rating_avg = COALESCE((
      SELECT ROUND(AVG(rating)::numeric, 1) FROM store_menu_comments
      WHERE menu_card_id = '7226cceb-d234-429b-bd4b-0fc60735bb3b'::uuid
        AND rating IS NOT NULL
    ), 0)
WHERE id = '7226cceb-d234-429b-bd4b-0fc60735bb3b'::uuid;

COMMIT;


-- ════════════════════════════════════════════════════════════════════════════
-- 검증 — 통합 후 결과
--
--   SELECT mc.id, mc.menu_name, mc.price, mc.is_featured,
--          mc.rating_avg, mc.rating_count,
--          (mc.image_url IS NOT NULL) AS has_thumb,
--          (SELECT COUNT(*) FROM store_menu_comments WHERE menu_card_id = mc.id) AS comments,
--          (SELECT COUNT(*) FROM store_menu_photos   WHERE menu_card_id = mc.id) AS photos
--   FROM store_menu_cards mc
--   WHERE mc.store_name = 'きたかた食堂 神保町店'
--   ORDER BY mc.menu_name;
--
--   기대 결과:
--     - 위스키          ¥1200, comments=1
--     - 中華そば醤油      ¥820,  rating_count=4 (1+1+2), comments=4, photos=1
--     - 平打ち冷し肉そば   ¥920,  comments=1
-- ════════════════════════════════════════════════════════════════════════════
