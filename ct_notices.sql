-- ════════════════════════════════════════════════════════════════════════════
-- 치리토크 상단 공지 카드 — ct_notices
--
--   치리토크 피드 상단 배너에 노출되는 공지/캠페인 카드를 어드민이 관리.
--   카드색·폰트색·폰트크기·태그색·이미지·노출기간·on/off·순서 지정 가능.
--
--   Supabase SQL Editor 에 그대로 붙여넣고 RUN.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE TABLE IF NOT EXISTS ct_notices (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tag         TEXT DEFAULT 'お知らせ',                  -- 태그 라벨
  text        TEXT NOT NULL,                            -- 본문
  bg_color    TEXT DEFAULT '#172C58',                   -- 카드 배경색
  text_color  TEXT DEFAULT '#FFFFFF',                   -- 본문 폰트색
  tag_bg      TEXT DEFAULT 'rgba(232,160,32,.22)',      -- 태그 배경색
  tag_color   TEXT DEFAULT '#E8A020',                   -- 태그 폰트색
  font_size   INT  DEFAULT 13,                          -- 본문 폰트 크기(px)
  image_url   TEXT,                                     -- 이미지(선택)
  starts_at   TIMESTAMPTZ DEFAULT NOW(),                -- 노출 시작
  ends_at     TIMESTAMPTZ,                              -- 노출 종료 (NULL = 무기한)
  is_active   BOOLEAN DEFAULT TRUE,                     -- on/off
  sort_order  INT DEFAULT 0,                            -- 정렬(작을수록 앞)
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ct_notices_active_idx ON ct_notices (is_active, sort_order, created_at DESC);

ALTER TABLE ct_notices ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ct_notices_select ON ct_notices;
DROP POLICY IF EXISTS ct_notices_insert ON ct_notices;
DROP POLICY IF EXISTS ct_notices_update ON ct_notices;
DROP POLICY IF EXISTS ct_notices_delete ON ct_notices;

-- 읽기: 활성 공지는 누구나 / 어드민은 전부 (비활성 포함)
CREATE POLICY ct_notices_select ON ct_notices FOR SELECT
  USING (
    is_active = TRUE
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE)
  );

-- 쓰기: 어드민만
CREATE POLICY ct_notices_insert ON ct_notices FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE));
CREATE POLICY ct_notices_update ON ct_notices FOR UPDATE
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE));
CREATE POLICY ct_notices_delete ON ct_notices FOR DELETE
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE));

-- 기존 하드코딩 공지 2개 시드 (배너 비지 않게)
INSERT INTO ct_notices (tag, text, bg_color, text_color, tag_bg, tag_color, font_size, sort_order)
VALUES
  ('お知らせ',   'v1.2.0 アップデート — 「チリつも公開」機能が追加されました 🎉',
     '#172C58', '#FFFFFF', 'rgba(232,160,32,.22)', '#E8A020', 13, 0),
  ('キャンペーン', '今週限定！レシート公開で +20チリ ボーナス実施中 ✨',
     '#FBF3E0', '#B8801A', '#E8A020', '#FFFFFF', 13, 1)
ON CONFLICT DO NOTHING;

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
-- 검증
--   SELECT id, tag, text, is_active, starts_at, ends_at FROM ct_notices ORDER BY sort_order;
-- ════════════════════════════════════════════════════════════════════════════
