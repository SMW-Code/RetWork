-- ============================================================
-- 가게 상세 모달 — 커뮤니티 테이블 + Storage 버킷
-- Supabase Dashboard → SQL Editor → 전체 붙여넣기 → Run
-- ============================================================

-- 1. 가게 사진
CREATE TABLE IF NOT EXISTS store_community_photos (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_name   TEXT NOT NULL,
  photo_url    TEXT NOT NULL,
  uploaded_by  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- 2. 메뉴 카드
CREATE TABLE IF NOT EXISTS store_menu_cards (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_name   TEXT NOT NULL,
  menu_name    TEXT NOT NULL,
  category     TEXT,
  price        INT,
  image_url    TEXT,
  rating_avg   NUMERIC(3,1) DEFAULT 0,
  rating_count INT DEFAULT 0,
  created_by   UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

-- 3. 메뉴 댓글 (유저당 1개 — UNIQUE 제약)
CREATE TABLE IF NOT EXISTS store_menu_comments (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  menu_card_id UUID REFERENCES store_menu_cards(id) ON DELETE CASCADE,
  user_id      UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  rating       INT CHECK (rating >= 1 AND rating <= 5),
  content      TEXT,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (menu_card_id, user_id)
);

-- 4. 대댓글 (유저당 여러 개 가능)
CREATE TABLE IF NOT EXISTS store_menu_replies (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  comment_id   UUID REFERENCES store_menu_comments(id) ON DELETE CASCADE,
  user_id      UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  content      TEXT NOT NULL,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ── RLS 활성화 ──
ALTER TABLE store_community_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_menu_cards       ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_menu_comments    ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_menu_replies     ENABLE ROW LEVEL SECURITY;

-- ── RLS 정책 ──
DO $$ BEGIN

  -- store_community_photos
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='store_community_photos' AND policyname='scp_read') THEN
    CREATE POLICY "scp_read"  ON store_community_photos FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='store_community_photos' AND policyname='scp_insert') THEN
    CREATE POLICY "scp_insert" ON store_community_photos FOR INSERT WITH CHECK (auth.uid() = uploaded_by);
  END IF;

  -- store_menu_cards
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='store_menu_cards' AND policyname='smc_read') THEN
    CREATE POLICY "smc_read"   ON store_menu_cards FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='store_menu_cards' AND policyname='smc_insert') THEN
    CREATE POLICY "smc_insert" ON store_menu_cards FOR INSERT WITH CHECK (auth.uid() = created_by);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='store_menu_cards' AND policyname='smc_update') THEN
    CREATE POLICY "smc_update" ON store_menu_cards FOR UPDATE USING (true);
  END IF;

  -- store_menu_comments
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='store_menu_comments' AND policyname='smcmt_read') THEN
    CREATE POLICY "smcmt_read"   ON store_menu_comments FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='store_menu_comments' AND policyname='smcmt_insert') THEN
    CREATE POLICY "smcmt_insert" ON store_menu_comments FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='store_menu_comments' AND policyname='smcmt_update') THEN
    CREATE POLICY "smcmt_update" ON store_menu_comments FOR UPDATE USING (auth.uid() = user_id);
  END IF;

  -- store_menu_replies
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='store_menu_replies' AND policyname='smr_read') THEN
    CREATE POLICY "smr_read"   ON store_menu_replies FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='store_menu_replies' AND policyname='smr_insert') THEN
    CREATE POLICY "smr_insert" ON store_menu_replies FOR INSERT WITH CHECK (auth.uid() = user_id);
  END IF;

END $$;

-- ── Storage 버킷 생성 (store-photos) ──
-- Supabase Dashboard → Storage → New Bucket 에서도 만들 수 있음
INSERT INTO storage.buckets (id, name, public)
VALUES ('store-photos', 'store-photos', true)
ON CONFLICT (id) DO NOTHING;

-- Storage 정책: 누구나 읽기, 로그인 유저 업로드
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='objects' AND policyname='store_photos_read') THEN
    CREATE POLICY "store_photos_read" ON storage.objects FOR SELECT USING (bucket_id = 'store-photos');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='objects' AND policyname='store_photos_upload') THEN
    CREATE POLICY "store_photos_upload" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'store-photos' AND auth.uid() IS NOT NULL);
  END IF;
END $$;

SELECT '✅ store_detail_tables.sql 적용 완료' AS result;
