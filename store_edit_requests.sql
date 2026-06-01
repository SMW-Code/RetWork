-- ════════════════════════════════════════════════════════════════════════════
-- 가게 수정요청 (store edit requests)
--   • 유저가 치리맵 가게상세모달에서 "✏️ 修正リクエスト" → 내용 기입 → 제출
--   • 어드민이 대시보드 "🛠 가게 수정요청" 카드에서 확인·처리(done)
--
--   Supabase SQL Editor 에 그대로 붙여넣고 RUN. (idempotent)
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE TABLE IF NOT EXISTS store_edit_requests (
  id          BIGSERIAL PRIMARY KEY,
  store_id    TEXT,                               -- stores.id 또는 식별자 (가변형이라 TEXT)
  store_name  TEXT NOT NULL,
  lat         DOUBLE PRECISION,
  lng         DOUBLE PRECISION,
  user_id     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  content     TEXT NOT NULL,                      -- 유저가 적은 수정 요청 내용
  status      TEXT NOT NULL DEFAULT 'open',       -- 'open' | 'done'
  admin_note  TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_ser_status_created
  ON store_edit_requests(status, created_at DESC);

ALTER TABLE store_edit_requests ENABLE ROW LEVEL SECURITY;

-- 유저: 본인 명의로만 작성
DO $$ BEGIN
  CREATE POLICY ser_insert_own ON store_edit_requests
    FOR INSERT WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 조회: 본인 것 + 어드민은 전체
DO $$ BEGIN
  CREATE POLICY ser_select ON store_edit_requests
    FOR SELECT USING (
      auth.uid() = user_id
      OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 수정(처리 완료 표시): 어드민만
DO $$ BEGIN
  CREATE POLICY ser_update_admin ON store_edit_requests
    FOR UPDATE USING (
      EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
-- 검증
--   INSERT INTO store_edit_requests(store_name, user_id, content)
--     VALUES ('테스트가게', auth.uid(), '폐점했어요');         -- 유저 세션
--   SELECT * FROM store_edit_requests ORDER BY created_at DESC; -- 어드민 세션
-- ════════════════════════════════════════════════════════════════════════════
