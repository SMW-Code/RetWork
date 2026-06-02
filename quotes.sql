-- ════════════════════════════════════════════════════════════════════════════
-- 홈 화면 명언 카드 관리
--
--   • 언어별(ja/ko/en/zh) 명언 등록 — 어드민이 CRUD
--   • 클라이언트는 활성 명언 목록 fetch → 날짜 기준 순환 (기존 정적 배열은 폴백 유지)
--
--   Supabase SQL Editor 에 그대로 붙여넣고 RUN (idempotent).
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE TABLE IF NOT EXISTS quotes (
  id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  lang        TEXT         NOT NULL CHECK (lang IN ('ja','ko','en','zh')),
  text        TEXT         NOT NULL,
  author      TEXT,
  is_active   BOOLEAN      NOT NULL DEFAULT true,
  sort_order  INT          NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
  created_by  UUID         REFERENCES auth.users(id)
);

CREATE INDEX IF NOT EXISTS idx_quotes_lang_active
  ON quotes(lang, is_active, sort_order);

CREATE OR REPLACE FUNCTION _quotes_touch_updated()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END $$;

DROP TRIGGER IF EXISTS quotes_updated_at ON quotes;
CREATE TRIGGER quotes_updated_at BEFORE UPDATE ON quotes
  FOR EACH ROW EXECUTE FUNCTION _quotes_touch_updated();

ALTER TABLE quotes ENABLE ROW LEVEL SECURITY;

-- 누구나 활성 명언 SELECT (앱 노출용)
DO $$ BEGIN
  CREATE POLICY quotes_select ON quotes
    FOR SELECT
    USING (
      is_active = true
      OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 어드민만 INSERT/UPDATE/DELETE
DO $$ BEGIN
  CREATE POLICY quotes_admin_write ON quotes FOR ALL
    USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true))
    WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
-- 검증
--   INSERT INTO quotes (lang, text) VALUES ('ko', '시작이 반이다');
--   SELECT lang, count(*) FROM quotes WHERE is_active GROUP BY lang;
-- ════════════════════════════════════════════════════════════════════════════
