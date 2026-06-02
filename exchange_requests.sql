-- ════════════════════════════════════════════════════════════════════════════
-- 치리스토어 교환요청 (Phase 3.C)
--
--   목적:
--     • 사용자가 치리스토어 상품 교환 신청 시 exchange_requests INSERT
--     • 코인 차감 + 재고 차감은 기존 ctStoreExchangeDB 가 처리 (변경 없음)
--     • 어드민이 처리 상태 (pending/shipped/completed/cancelled) 변경
--
--   Supabase SQL Editor 에 그대로 붙여넣고 RUN (idempotent).
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE TABLE IF NOT EXISTS exchange_requests (
  id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID         NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  item_id         UUID         REFERENCES store_items(id) ON DELETE SET NULL,
  item_name       TEXT,                       -- 스냅샷 (상품 삭제/이름 변경 대비)
  item_image_url  TEXT,                       -- 스냅샷
  cost_chiri      INT          NOT NULL,
  status          TEXT         NOT NULL DEFAULT 'pending',  -- pending/shipped/completed/cancelled
  delivery_info   TEXT,                       -- 사용자 입력 배송/연락 정보 (선택)
  admin_note      TEXT,                       -- 운영자 메모
  user_email      TEXT,                       -- 스냅샷 (조회 편의)
  user_nickname   TEXT,                       -- 스냅샷
  created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
  processed_by    UUID         REFERENCES auth.users(id),
  processed_at    TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_exr_user   ON exchange_requests(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_exr_status ON exchange_requests(status, created_at DESC);

-- updated_at 자동 갱신
CREATE OR REPLACE FUNCTION _exr_touch_updated()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END $$;

DROP TRIGGER IF EXISTS exr_updated_at ON exchange_requests;
CREATE TRIGGER exr_updated_at BEFORE UPDATE ON exchange_requests
  FOR EACH ROW EXECUTE FUNCTION _exr_touch_updated();

ALTER TABLE exchange_requests ENABLE ROW LEVEL SECURITY;

-- 본인만 INSERT
DO $$ BEGIN
  CREATE POLICY exr_user_insert ON exchange_requests
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 본인 + 어드민 SELECT
DO $$ BEGIN
  CREATE POLICY exr_user_select ON exchange_requests
    FOR SELECT TO authenticated
    USING (
      user_id = auth.uid()
      OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 어드민만 UPDATE
DO $$ BEGIN
  CREATE POLICY exr_admin_update ON exchange_requests
    FOR UPDATE TO authenticated
    USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true))
    WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
-- 검증
--   SELECT status, count(*) FROM exchange_requests GROUP BY status;
--   SELECT * FROM exchange_requests ORDER BY created_at DESC LIMIT 10;
-- ════════════════════════════════════════════════════════════════════════════
