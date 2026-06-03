-- ════════════════════════════════════════════════════════════════════════════
-- 어드민 → 특정 유저 쪽지/메시지 시스템
--
--   • 어드민이 특정 사용자(1:1, 1:N, 전체) 에게 제목+본문+우선순위 메시지 전송
--   • 사용자는 받은 쪽지함에서 확인, 자동 읽음 처리
--   • 우선순위(low/normal/high/urgent), 만료 시간, 클릭 링크 옵션
--
--   Supabase SQL Editor 에 그대로 붙여넣고 RUN (idempotent).
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE TABLE IF NOT EXISTS admin_messages (
  id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id  UUID         NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  sender_id     UUID         REFERENCES auth.users(id),                       -- 어드민 발송자
  title         TEXT         NOT NULL,
  body          TEXT         NOT NULL,
  priority      TEXT         NOT NULL DEFAULT 'normal'
                CHECK (priority IN ('low','normal','high','urgent')),
  link_url      TEXT,                                                          -- 클릭 시 이동할 URL (외부 링크/딥링크)
  is_read       BOOLEAN      NOT NULL DEFAULT false,
  read_at       TIMESTAMPTZ,
  expires_at    TIMESTAMPTZ,                                                   -- 자동 만료 (NULL = 만료 없음)
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_am_recipient_created  ON admin_messages(recipient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_am_recipient_unread   ON admin_messages(recipient_id, is_read);
CREATE INDEX IF NOT EXISTS idx_am_sender_created     ON admin_messages(sender_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_am_expires            ON admin_messages(expires_at) WHERE expires_at IS NOT NULL;

ALTER TABLE admin_messages ENABLE ROW LEVEL SECURITY;

-- 본인 메시지 SELECT (만료된 거 제외)
DO $$ BEGIN
  CREATE POLICY am_user_select ON admin_messages FOR SELECT TO authenticated
    USING (
      recipient_id = auth.uid()
      AND (expires_at IS NULL OR expires_at > now())
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 본인이 자신의 is_read/read_at 만 UPDATE
DO $$ BEGIN
  CREATE POLICY am_user_mark_read ON admin_messages FOR UPDATE TO authenticated
    USING (recipient_id = auth.uid())
    WITH CHECK (recipient_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 어드민 ALL (조회/생성/수정/삭제)
DO $$ BEGIN
  CREATE POLICY am_admin_all ON admin_messages FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true))
    WITH CHECK (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- RPC 1: 어드민이 N명에게 한 번에 발송 (1명도 가능 — 배열에 1개)
--   p_recipient_ids: UUID[]  → 발송 대상 사용자 ID 배열
--   p_title, p_body          → 제목/본문
--   p_priority               → 'low'|'normal'|'high'|'urgent' (기본 'normal')
--   p_link_url               → 클릭 시 이동 URL (NULL 허용)
--   p_expires_at             → 만료 시각 (NULL = 영구)
--   반환: { ok, sent: N, err? }
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_send_message(
  p_recipient_ids UUID[],
  p_title TEXT,
  p_body TEXT,
  p_priority TEXT DEFAULT 'normal',
  p_link_url TEXT DEFAULT NULL,
  p_expires_at TIMESTAMPTZ DEFAULT NULL
) RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_admin UUID := auth.uid();
  v_count INT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = v_admin AND is_admin = true) THEN
    RETURN json_build_object('ok', false, 'err', 'forbidden');
  END IF;
  IF p_recipient_ids IS NULL OR array_length(p_recipient_ids, 1) IS NULL THEN
    RETURN json_build_object('ok', false, 'err', 'no_recipients');
  END IF;
  IF p_title IS NULL OR length(trim(p_title)) = 0 THEN
    RETURN json_build_object('ok', false, 'err', 'no_title');
  END IF;
  IF p_body IS NULL OR length(trim(p_body)) = 0 THEN
    RETURN json_build_object('ok', false, 'err', 'no_body');
  END IF;
  IF p_priority NOT IN ('low','normal','high','urgent') THEN
    p_priority := 'normal';
  END IF;

  INSERT INTO admin_messages(recipient_id, sender_id, title, body, priority, link_url, expires_at)
  SELECT unnest(p_recipient_ids), v_admin, p_title, p_body, p_priority, p_link_url, p_expires_at;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN json_build_object('ok', true, 'sent', v_count);
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- RPC 2: 전체 사용자에게 broadcast (삭제 안 된 모든 profiles 대상)
--   ⚠️ 위험 — 어드민 UI 에서 한 번 더 확인 절차 권장
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION admin_broadcast_message(
  p_title TEXT,
  p_body TEXT,
  p_priority TEXT DEFAULT 'normal',
  p_link_url TEXT DEFAULT NULL,
  p_expires_at TIMESTAMPTZ DEFAULT NULL
) RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_admin UUID := auth.uid();
  v_count INT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = v_admin AND is_admin = true) THEN
    RETURN json_build_object('ok', false, 'err', 'forbidden');
  END IF;
  IF p_title IS NULL OR length(trim(p_title)) = 0 OR p_body IS NULL OR length(trim(p_body)) = 0 THEN
    RETURN json_build_object('ok', false, 'err', 'invalid_input');
  END IF;
  IF p_priority NOT IN ('low','normal','high','urgent') THEN
    p_priority := 'normal';
  END IF;

  INSERT INTO admin_messages(recipient_id, sender_id, title, body, priority, link_url, expires_at)
  SELECT id, v_admin, p_title, p_body, p_priority, p_link_url, p_expires_at
    FROM profiles
   WHERE deleted_at IS NULL;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN json_build_object('ok', true, 'sent', v_count);
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- RPC 3: 안 읽은 메시지 수 조회 (홈 헤더 배지용)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_unread_admin_messages_count()
RETURNS INT LANGUAGE plpgsql SECURITY DEFINER SET search_path = public STABLE AS $$
DECLARE v_n INT;
BEGIN
  SELECT COUNT(*) INTO v_n FROM admin_messages
   WHERE recipient_id = auth.uid()
     AND is_read = false
     AND (expires_at IS NULL OR expires_at > now());
  RETURN COALESCE(v_n, 0);
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- RPC 4: 읽음 처리 (단건 또는 전체)
--   p_message_id NULL 이면 본인의 모든 안 읽은 메시지 → 읽음
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION mark_admin_message_read(p_message_id UUID DEFAULT NULL)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_count INT;
BEGIN
  IF p_message_id IS NULL THEN
    UPDATE admin_messages
       SET is_read = true, read_at = now()
     WHERE recipient_id = auth.uid()
       AND is_read = false
       AND (expires_at IS NULL OR expires_at > now());
  ELSE
    UPDATE admin_messages
       SET is_read = true, read_at = now()
     WHERE id = p_message_id
       AND recipient_id = auth.uid()
       AND is_read = false;
  END IF;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN json_build_object('ok', true, 'updated', v_count);
END $$;

GRANT EXECUTE ON FUNCTION admin_send_message(UUID[], TEXT, TEXT, TEXT, TEXT, TIMESTAMPTZ)         TO authenticated;
GRANT EXECUTE ON FUNCTION admin_broadcast_message(TEXT, TEXT, TEXT, TEXT, TIMESTAMPTZ)            TO authenticated;
GRANT EXECUTE ON FUNCTION get_unread_admin_messages_count()                                       TO authenticated;
GRANT EXECUTE ON FUNCTION mark_admin_message_read(UUID)                                           TO authenticated;

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
-- 검증
--   -- 1명 발송
--   SELECT admin_send_message(ARRAY['<user-uid>']::UUID[], '환영합니다', '본문 내용', 'normal', NULL, NULL);
--   -- 다중 발송
--   SELECT admin_send_message(ARRAY['<uid1>','<uid2>']::UUID[], '안내', '...', 'high', 'https://retwork.jp/about', now() + interval '7 days');
--   -- 전체 발송
--   SELECT admin_broadcast_message('점검 안내', '오늘 22시~23시 점검 예정', 'urgent', NULL, now() + interval '1 day');
--   -- 사용자 측 확인
--   SELECT get_unread_admin_messages_count();
--   SELECT * FROM admin_messages WHERE recipient_id = auth.uid() ORDER BY created_at DESC LIMIT 10;
--   -- 읽음 처리
--   SELECT mark_admin_message_read('<message-id>');
--   SELECT mark_admin_message_read(NULL);  -- 전체 일괄
-- ════════════════════════════════════════════════════════════════════════════
