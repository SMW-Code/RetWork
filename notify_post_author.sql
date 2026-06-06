-- ════════════════════════════════════════════════════════════════════════════
-- 치리토크 알림 보안 강화 — 서버에서만 알림 생성 (notify_post_author RPC)
--
--   문제: ct_notifications INSERT 정책이 CHECK=true → 누구나 콘솔에서 아무에게나
--         "운영팀 사칭" 가짜 알림/스팸을 꽂을 수 있었음 (보낸사람 검증 컬럼 없음).
--   해결: 직접 INSERT 차단 + SECURITY DEFINER RPC 로만 알림 생성.
--         보낸사람(from_user_id, from_user_name)을 서버가 auth.uid() 기준으로 박음
--         → 사칭 불가. 게시글 작성자에게만, 본인 글엔 안 보냄.
--
--   알림은 좋아요/댓글 시 자동 생성뿐(유저간 메시지 기능 없음)이라 이 RPC로 충분.
--   Supabase SQL Editor 에서 실행 (idempotent).
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- 보낸사람 검증 컬럼 (서버가 auth.uid() 로 박음 — 위조 불가)
ALTER TABLE ct_notifications ADD COLUMN IF NOT EXISTS from_user_id UUID;

-- 게시글 작성자에게 알림 (좋아요/댓글) — 서버 권한
CREATE OR REPLACE FUNCTION notify_post_author(
  p_post_id UUID,
  p_type    TEXT,
  p_content TEXT DEFAULT NULL,
  p_avatar  TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user      UUID := auth.uid();
  v_recipient UUID;
  v_title     TEXT;
  v_name      TEXT;
BEGIN
  IF v_user IS NULL THEN
    RETURN json_build_object('ok', false, 'err', 'not_logged_in');
  END IF;
  IF p_type NOT IN ('like', 'comment') THEN
    RETURN json_build_object('ok', false, 'err', 'invalid_type');
  END IF;

  -- 게시글 작성자 / 제목 조회
  SELECT user_id, title INTO v_recipient, v_title FROM ct_posts WHERE id = p_post_id;
  IF v_recipient IS NULL THEN
    RETURN json_build_object('ok', false, 'err', 'no_post');
  END IF;
  -- 본인 글이면 알림 안 보냄
  IF v_recipient = v_user THEN
    RETURN json_build_object('ok', true, 'skipped', 'self');
  END IF;

  -- 보낸사람 닉네임은 서버가 profiles 에서 (위조 불가). 아바타는 이모지라 클라값 허용.
  SELECT nickname INTO v_name FROM profiles WHERE id = v_user;

  INSERT INTO ct_notifications
    (recipient_id, type, post_id, post_title, from_user_id, from_user_name, from_user_avatar, content)
  VALUES
    (v_recipient, p_type, p_post_id, v_title, v_user, COALESCE(v_name, '名無し'), p_avatar, p_content);

  RETURN json_build_object('ok', true);
END $$;

GRANT EXECUTE ON FUNCTION notify_post_author(UUID, TEXT, TEXT, TEXT) TO authenticated;

-- 직접 INSERT 차단: 기존 CHECK=true 정책 제거.
-- 정책 없음 = deny. 알림은 위 RPC(SECURITY DEFINER, RLS 우회)로만 생성됨.
DROP POLICY IF EXISTS auth_insert_ct_notif    ON ct_notifications;
DROP POLICY IF EXISTS auth_insert_ct_notif_v2 ON ct_notifications;
-- (SELECT=recipient 본인, UPDATE=recipient 본인 정책은 그대로 유지)

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
-- 검증
--   SELECT notify_post_author('<남의 게시글 UUID>', 'like', NULL, '😊');  -- {ok:true}
--   SELECT notify_post_author('<내 게시글 UUID>',   'like', NULL, '😊');  -- {ok:true, skipped:self}
--   -- 직접 INSERT 시도는 이제 거부돼야 함:
--   INSERT INTO ct_notifications(recipient_id,type) VALUES (auth.uid(),'like');  -- RLS 거부
-- ════════════════════════════════════════════════════════════════════════════
