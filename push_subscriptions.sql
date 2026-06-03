-- ════════════════════════════════════════════════════════════════════════════
-- 푸시 알림 구독 (Web Push API)
--
--   • 한 사용자가 여러 디바이스(아이폰 PWA, 안드로이드 Chrome, PC 등) 등록 가능
--   • endpoint 가 UNIQUE — 같은 디바이스 재구독 시 upsert
--   • RLS: 본인만 조회/생성/삭제, 어드민은 발송용 전체 조회
--   • web-push 라이브러리는 endpoint + p256dh + auth 3개 필드만 필요
--
--   Supabase SQL Editor 에 그대로 붙여넣고 RUN (idempotent).
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE TABLE IF NOT EXISTS push_subscriptions (
  id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID         NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  endpoint      TEXT         NOT NULL UNIQUE,             -- PushManager.subscribe() 의 endpoint
  p256dh        TEXT         NOT NULL,                    -- 공개키
  auth          TEXT         NOT NULL,                    -- auth secret
  device_label  TEXT,                                      -- 'iOS Safari' / 'Android Chrome' / 'Windows Edge' 등
  user_agent    TEXT,                                      -- 브라우저 UA (디버그용)
  enabled       BOOLEAN      NOT NULL DEFAULT true,        -- 사용자 토글 (설정창)
  last_sent_at  TIMESTAMPTZ,                              -- 마지막 발송 성공 시각
  last_error    TEXT,                                      -- 마지막 발송 실패 사유 (410 Gone 등)
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ps_user     ON push_subscriptions(user_id, enabled);
CREATE INDEX IF NOT EXISTS idx_ps_endpoint ON push_subscriptions(endpoint);

ALTER TABLE push_subscriptions ENABLE ROW LEVEL SECURITY;

-- 본인만 자신의 구독 조회/관리
DO $$ BEGIN
  CREATE POLICY ps_user_select ON push_subscriptions FOR SELECT TO authenticated
    USING (
      user_id = auth.uid()
      OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY ps_user_upsert ON push_subscriptions FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY ps_user_update ON push_subscriptions FOR UPDATE TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE POLICY ps_user_delete ON push_subscriptions FOR DELETE TO authenticated
    USING (
      user_id = auth.uid()
      OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- updated_at 트리거
CREATE OR REPLACE FUNCTION _ps_touch_updated()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END $$;

DROP TRIGGER IF EXISTS ps_updated_at ON push_subscriptions;
CREATE TRIGGER ps_updated_at BEFORE UPDATE ON push_subscriptions
  FOR EACH ROW EXECUTE FUNCTION _ps_touch_updated();

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
-- 검증
--   SELECT * FROM push_subscriptions WHERE user_id = auth.uid();
--   -- 디바이스 삭제 (사용자가 알림 해제 시)
--   DELETE FROM push_subscriptions WHERE id = '<sub-id>' AND user_id = auth.uid();
-- ════════════════════════════════════════════════════════════════════════════
