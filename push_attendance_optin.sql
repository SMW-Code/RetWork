-- ════════════════════════════════════════════════════════════════════════════
-- 출석 알림 옵트인 (build 317)
--
--   push_subscriptions 테이블에 attendance_optin 컬럼 추가.
--   사용자가 설정창에서 토글 ON 시 true → cron 푸시 발송 대상.
--   기본 true (옵트아웃 모델 — 푸시 알림 켠 사용자는 출석 알림도 기본 ON).
--
--   Supabase SQL Editor 에서 실행 (idempotent).
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

ALTER TABLE push_subscriptions
  ADD COLUMN IF NOT EXISTS attendance_optin BOOLEAN NOT NULL DEFAULT true;

-- 본인이 자신의 attendance_optin 만 UPDATE 가능 (기존 UPDATE 정책 안에 포함됨)
-- 추가 정책 불필요

CREATE INDEX IF NOT EXISTS idx_ps_attendance_optin
  ON push_subscriptions(attendance_optin)
  WHERE enabled = true AND attendance_optin = true;

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
-- 검증
--   SELECT count(*) FROM push_subscriptions WHERE enabled = true AND attendance_optin = true;
--   -- 출석 알림 받을 활성 구독자 수
-- ════════════════════════════════════════════════════════════════════════════
