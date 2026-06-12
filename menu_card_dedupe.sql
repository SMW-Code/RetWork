-- ════════════════════════════════════════════════════════════════════════════
-- store_menu_cards 중복 카드 정리 (b449)
--   같은 store_name + 같은(정규화) menu_name 카드가 2개 이상이면
--   가장 오래된 카드(keeper)로 평점·코멘트·사진을 합치고 나머지를 삭제.
--   정규화 = 공백 제거 + 소문자.
--
--   ⚠️ 데이터 변경(병합/삭제)이므로 실행 전 백업 권장.
--      Supabase → Database → Backups, 또는 아래로 사전 확인:
--        SELECT store_name, menu_name, count(*) FROM store_menu_cards
--        GROUP BY store_name, regexp_replace(lower(menu_name),'\s+','','g')
--        HAVING count(*) > 1;
--   idempotent — 중복이 없으면 아무것도 안 바뀜.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- 그룹별 keeper(가장 오래된 카드) 매핑
CREATE TEMP TABLE _dup ON COMMIT DROP AS
SELECT id,
       store_name,
       FIRST_VALUE(id) OVER (
         PARTITION BY store_name, regexp_replace(lower(menu_name), '\s+', '', 'g')
         ORDER BY created_at ASC, id ASC
       ) AS keep_id
FROM store_menu_cards;

-- 1) keeper 의 대표 이미지가 비어 있으면 그룹 내 아무 이미지로 채움 (삭제 전에)
UPDATE store_menu_cards smc
   SET image_url = sub.img
FROM (
  SELECT d.keep_id,
         (array_agg(c.image_url) FILTER (WHERE c.image_url IS NOT NULL AND c.image_url <> ''))[1] AS img
  FROM _dup d
  JOIN store_menu_cards c ON c.id = d.id
  GROUP BY d.keep_id
) sub
WHERE smc.id = sub.keep_id
  AND (smc.image_url IS NULL OR smc.image_url = '')
  AND sub.img IS NOT NULL;

-- 2) 코멘트 이전 — keeper 에 같은 user 코멘트가 이미 있으면 중복분 삭제(UNIQUE 충돌 방지)
DELETE FROM store_menu_comments c
USING _dup d
WHERE c.menu_card_id = d.id
  AND d.id <> d.keep_id
  AND EXISTS (
    SELECT 1 FROM store_menu_comments k
     WHERE k.menu_card_id = d.keep_id AND k.user_id = c.user_id
  );

UPDATE store_menu_comments c
   SET menu_card_id = d.keep_id
FROM _dup d
WHERE c.menu_card_id = d.id AND d.id <> d.keep_id;

-- 3) 추가 사진 이전
UPDATE store_menu_photos p
   SET menu_card_id = d.keep_id
FROM _dup d
WHERE p.menu_card_id = d.id AND d.id <> d.keep_id;

-- 4) 중복 카드 삭제
DELETE FROM store_menu_cards
WHERE id IN (SELECT id FROM _dup WHERE id <> keep_id);

-- 5) keeper 평점 재계산
UPDATE store_menu_cards smc
   SET rating_count = sub.cnt,
       rating_avg   = sub.avg
FROM (
  SELECT menu_card_id,
         COUNT(rating)                      AS cnt,
         COALESCE(ROUND(AVG(rating), 1), 0) AS avg
  FROM store_menu_comments
  WHERE rating IS NOT NULL
  GROUP BY menu_card_id
) sub
WHERE smc.id = sub.menu_card_id;

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
-- 검증 — 남은 중복이 0 이어야 함
--   SELECT store_name, menu_name, count(*) FROM store_menu_cards
--   GROUP BY store_name, regexp_replace(lower(menu_name),'\s+','','g')
--   HAVING count(*) > 1;
-- ════════════════════════════════════════════════════════════════════════════
