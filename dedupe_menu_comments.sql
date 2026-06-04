-- ════════════════════════════════════════════════════════════════════════════
-- 메뉴 카드 댓글 중복 텍스트 정리 (build 364)
--
--   기존 build 348 이전 흐름에서 치리 공개 시 한 영수증의 모든 메뉴 카드에
--   같은 commentText 가 복제 insert 됨 → 메뉴 카드별로 동일 댓글이 노출되는 문제.
--
--   해결: 같은 (store_name, user_id, content) 가 여러 메뉴 카드에 있으면
--         가장 오래된 1개만 content 유지, 나머지는 content NULL 처리.
--         (rating 은 보존 — 별점 분포는 계속 카운트됨)
--
--   앞으로의 흐름은 build 364 코드 수정으로 자동 분리됨 (메뉴별 content 는 항상 NULL,
--   사용자가 메뉴 카드 상세에서 직접 입력한 댓글만 표시).
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

WITH ranked AS (
  SELECT smc.id,
         ROW_NUMBER() OVER (
           PARTITION BY mc.store_name, smc.user_id, smc.content
           ORDER BY smc.created_at ASC
         ) AS rn
  FROM store_menu_comments smc
  JOIN store_menu_cards mc ON mc.id = smc.menu_card_id
  WHERE smc.content IS NOT NULL
)
UPDATE store_menu_comments
SET content = NULL
WHERE id IN (SELECT id FROM ranked WHERE rn > 1);

COMMIT;


-- ════════════════════════════════════════════════════════════════════════════
-- 검증 — 메뉴 카드별 댓글 (content NOT NULL 만)
--
--   SELECT mc.store_name, mc.menu_name,
--          smc.user_id, smc.rating, smc.content, smc.created_at
--   FROM store_menu_comments smc
--   JOIN store_menu_cards mc ON mc.id = smc.menu_card_id
--   WHERE smc.content IS NOT NULL
--   ORDER BY mc.store_name, mc.menu_name, smc.created_at;
--
--   기대: 같은 (store_name, user_id, content) 는 row 1개씩만 (가장 오래된 것)
-- ════════════════════════════════════════════════════════════════════════════
