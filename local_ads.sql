-- ════════════════════════════════════════════════════════════════════════════
-- 로컬 광고 시스템 + 광고 수익 기록
--
--  • local_ads     : 어드민이 직접 올리는 자체 배너 광고 (이미지 + 링크 + 영역 + 기간)
--  • ad_revenue    : 영역/월별 수익 수동 입력 (AdSense 실수익은 자동조회 불가 → 수동)
--  • local_ad_bump : 노출/클릭 카운트 증가용 RPC (anon 도 호출 가능, SECURITY DEFINER)
--
-- 이미지는 기존 'store-photos' Storage 버킷 재사용 (path 접두사 local-ads/).
-- Supabase SQL Editor 에 그대로 붙여넣고 RUN.
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── 1) 로컬 광고 테이블 ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS local_ads (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title       TEXT NOT NULL,                 -- 광고주/메모 (내부 식별용)
  image_url   TEXT,                          -- 배너 이미지 URL
  link_url    TEXT,                          -- 클릭 시 이동 URL (가게/외부)
  zone        TEXT NOT NULL,                 -- home / store / feed / reward / map / modal
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  start_at    TIMESTAMPTZ,                   -- 게재 시작 (NULL = 즉시)
  end_at      TIMESTAMPTZ,                   -- 게재 종료 (NULL = 무기한)
  sort_order  INT NOT NULL DEFAULT 0,
  impressions BIGINT NOT NULL DEFAULT 0,
  clicks      BIGINT NOT NULL DEFAULT 0,
  width_pct   INT NOT NULL DEFAULT 100,   -- 노출 영역 폭 대비 % (30~100)
  aspect_pct  INT NOT NULL DEFAULT 40,    -- 세로/가로 비율 % (10~100, 100=정사각)
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- 기존 테이블에 컬럼 추가 (이미 만든 사용자 대상)
ALTER TABLE local_ads
  ADD COLUMN IF NOT EXISTS width_pct  INT NOT NULL DEFAULT 100,
  ADD COLUMN IF NOT EXISTS aspect_pct INT NOT NULL DEFAULT 40;
CREATE INDEX IF NOT EXISTS idx_local_ads_zone   ON local_ads(zone);
CREATE INDEX IF NOT EXISTS idx_local_ads_active ON local_ads(is_active);

-- updated_at 자동 갱신
CREATE OR REPLACE FUNCTION local_ads_touch()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$;
DROP TRIGGER IF EXISTS local_ads_touch_trg ON local_ads;
CREATE TRIGGER local_ads_touch_trg BEFORE UPDATE ON local_ads
  FOR EACH ROW EXECUTE FUNCTION local_ads_touch();

ALTER TABLE local_ads ENABLE ROW LEVEL SECURITY;

-- 누구나 활성 광고 SELECT (앱 노출용)
DROP POLICY IF EXISTS local_ads_select ON local_ads;
CREATE POLICY local_ads_select ON local_ads
  FOR SELECT USING (
    is_active = TRUE
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE)
  );

-- 어드민만 INSERT/UPDATE/DELETE
DROP POLICY IF EXISTS local_ads_admin_write ON local_ads;
CREATE POLICY local_ads_admin_write ON local_ads
  FOR ALL
  USING      (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE));

-- ── 2) 노출/클릭 카운트 RPC (anon 포함 누구나 호출, RLS 우회) ──────────────
CREATE OR REPLACE FUNCTION local_ad_bump(p_id UUID, p_kind TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_kind = 'click' THEN
    UPDATE local_ads SET clicks = clicks + 1 WHERE id = p_id;
  ELSE
    UPDATE local_ads SET impressions = impressions + 1 WHERE id = p_id;
  END IF;
END; $$;
GRANT EXECUTE ON FUNCTION local_ad_bump(UUID, TEXT) TO anon, authenticated;

-- ── 3) 광고 수익 수동 기록 테이블 ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS ad_revenue (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  month       TEXT NOT NULL,                       -- 'YYYY-MM'
  zone        TEXT NOT NULL DEFAULT 'all',          -- home/store/... 또는 'all'
  source      TEXT NOT NULL DEFAULT 'adsense',      -- adsense / local / other
  amount_jpy  NUMERIC NOT NULL DEFAULT 0,
  note        TEXT,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  UNIQUE (month, zone, source)
);
CREATE INDEX IF NOT EXISTS idx_ad_revenue_month ON ad_revenue(month);

ALTER TABLE ad_revenue ENABLE ROW LEVEL SECURITY;

-- 어드민만 SELECT + 쓰기 (수익은 운영 정보 → 일반 노출 X)
DROP POLICY IF EXISTS ad_revenue_admin ON ad_revenue;
CREATE POLICY ad_revenue_admin ON ad_revenue
  FOR ALL
  USING      (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE))
  WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = TRUE));

-- Realtime (선택)
DO $$ BEGIN
  PERFORM 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='local_ads';
  IF NOT FOUND THEN EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE local_ads'; END IF;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'realtime local_ads skip: %', SQLERRM; END $$;

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
-- 검증
--   SELECT zone, count(*), sum(impressions), sum(clicks) FROM local_ads GROUP BY zone;
--   SELECT * FROM ad_revenue ORDER BY month DESC;
-- ════════════════════════════════════════════════════════════════════════════
