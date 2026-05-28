-- ════════════════════════════════════════════════════════════════════════════
-- i18n CMS — 어드민이 편집 가능한 번역 테이블
--
-- 정적 I18N 객체 위에 덮어쓰는 override 레이어. 정적 fallback 이 안전망.
-- 누구나 SELECT (앱 로드용), 어드민만 INSERT/UPDATE/DELETE.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE TABLE IF NOT EXISTS i18n_translations (
  key         TEXT NOT NULL,
  lang        TEXT NOT NULL CHECK (lang IN ('ja','ko','en','zh')),
  value       TEXT NOT NULL,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  PRIMARY KEY (key, lang)
);

CREATE INDEX IF NOT EXISTS idx_i18n_key  ON i18n_translations(key);
CREATE INDEX IF NOT EXISTS idx_i18n_lang ON i18n_translations(lang);

-- updated_at 자동 갱신
CREATE OR REPLACE FUNCTION i18n_touch_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  NEW.updated_by = auth.uid();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS i18n_touch_updated_at_trg ON i18n_translations;
CREATE TRIGGER i18n_touch_updated_at_trg
  BEFORE INSERT OR UPDATE ON i18n_translations
  FOR EACH ROW EXECUTE FUNCTION i18n_touch_updated_at();

-- RLS
ALTER TABLE i18n_translations ENABLE ROW LEVEL SECURITY;

-- 누구나 SELECT (앱 첫 로드용 — anon 포함)
DROP POLICY IF EXISTS i18n_select_all ON i18n_translations;
CREATE POLICY i18n_select_all ON i18n_translations
  FOR SELECT
  USING (true);

-- 어드민만 INSERT/UPDATE/DELETE
DROP POLICY IF EXISTS i18n_admin_write ON i18n_translations;
CREATE POLICY i18n_admin_write ON i18n_translations
  FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true));

-- Realtime publication 등록 (Supabase Dashboard에서도 가능)
DO $$ BEGIN
  PERFORM 1 FROM pg_publication_tables
   WHERE pubname = 'supabase_realtime' AND tablename = 'i18n_translations';
  IF NOT FOUND THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE i18n_translations';
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'realtime publication 등록 실패 (무시): %', SQLERRM;
END $$;

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
-- 검증
-- ════════════════════════════════════════════════════════════════════════════
-- SELECT key, lang, LEFT(value,30) FROM i18n_translations ORDER BY key, lang LIMIT 20;
-- SELECT policyname, cmd FROM pg_policies WHERE tablename = 'i18n_translations';
