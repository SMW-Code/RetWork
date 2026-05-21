-- ============================================================
-- チリつも × ReceiptIQ — Supabase 추가 테이블 SQL
-- 실행 방법: Supabase Dashboard → SQL Editor → 붙여넣기 → Run
-- 기존 receipts, items 테이블은 건드리지 않음
-- ============================================================


-- ────────────────────────────────────────
-- STEP 1. 기존 receipts 테이블에 컬럼 추가
-- (チリつも 지도 공개 여부)
-- ────────────────────────────────────────
ALTER TABLE receipts
  ADD COLUMN IF NOT EXISTS is_public   BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS place_id    TEXT,
  ADD COLUMN IF NOT EXISTS store_category TEXT;


-- ────────────────────────────────────────
-- STEP 2. 유저 프로필
-- (Supabase Auth와 연동 — auth.users 확장)
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS profiles (
  id             UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nickname       TEXT NOT NULL DEFAULT '名無し',
  referral_code  TEXT UNIQUE,
  referred_by    UUID REFERENCES profiles(id),
  level          INT  DEFAULT 0,
  coin_balance   INT  DEFAULT 0,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- 신규 가입 시 프로필 자동 생성
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  new_code TEXT;
BEGIN
  -- 8자리 추천코드 자동 생성
  new_code := upper(substring(gen_random_uuid()::text from 1 for 8));
  INSERT INTO profiles (id, nickname, referral_code)
  VALUES (NEW.id, '節約ユーザー', new_code);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();


-- ────────────────────────────────────────
-- STEP 3. 가게 정보
-- (Google Places 연동, 지도 핀의 기준)
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS stores (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  place_id       TEXT UNIQUE,          -- Google Places ID
  name           TEXT NOT NULL,
  address        TEXT,
  lat            FLOAT NOT NULL,
  lng            FLOAT NOT NULL,
  category       TEXT,                 -- 定食/ラーメン/カフェ...
  receipt_count  INT  DEFAULT 0,       -- 기여된 영수증 수 (집계)
  avg_price      INT  DEFAULT 0,       -- 평균 가격 (집계)
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS stores_lat_lng_idx ON stores (lat, lng);
CREATE INDEX IF NOT EXISTS stores_place_id_idx ON stores (place_id);


-- ────────────────────────────────────────
-- STEP 4. 가격 핀
-- (영수증 공개 시 지도에 표시되는 핵심 데이터)
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS price_pins (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id    UUID REFERENCES stores(id) ON DELETE CASCADE,
  receipt_id  UUID REFERENCES receipts(id) ON DELETE CASCADE,
  user_id     UUID REFERENCES profiles(id),
  item_name   TEXT,          -- 대표 메뉴명 (牛丼並盛り)
  price       INT NOT NULL,  -- 가격 (¥430)
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS price_pins_store_id_idx ON price_pins (store_id);


-- ────────────────────────────────────────
-- STEP 5. 가게 반응
-- (싸다 / 비싸다 / 가성비 좋다)
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS store_reactions (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id   UUID REFERENCES stores(id) ON DELETE CASCADE,
  user_id    UUID REFERENCES profiles(id) ON DELETE CASCADE,
  reaction   TEXT CHECK (reaction IN ('cheap', 'expensive', 'good_value')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (store_id, user_id)  -- 1인 1반응
);


-- ────────────────────────────────────────
-- STEP 6. 찜 목록 (お気に入り)
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS store_bookmarks (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id   UUID REFERENCES stores(id) ON DELETE CASCADE,
  user_id    UUID REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (store_id, user_id)  -- 중복 찜 방지
);


-- ────────────────────────────────────────
-- STEP 7. 커뮤니티 게시글 (節約部屋)
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS posts (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID REFERENCES profiles(id) ON DELETE CASCADE,
  category      TEXT CHECK (category IN (
                  'free',    -- 雑談
                  'humor',   -- 笑える
                  'fridge',  -- 冷蔵庫パ
                  'invest',  -- 投資
                  'romance', -- 恋愛
                  'tips'     -- 節約術
                )) DEFAULT 'free',
  title         TEXT NOT NULL,
  content       TEXT NOT NULL,
  image_urls    TEXT[],          -- 최대 5장
  like_count    INT DEFAULT 0,
  comment_count INT DEFAULT 0,
  is_best       BOOLEAN DEFAULT FALSE,  -- 베스트 게시글
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS posts_category_idx   ON posts (category);
CREATE INDEX IF NOT EXISTS posts_created_at_idx ON posts (created_at DESC);


-- ────────────────────────────────────────
-- STEP 8. 댓글
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS post_comments (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id    UUID REFERENCES posts(id) ON DELETE CASCADE,
  user_id    UUID REFERENCES profiles(id) ON DELETE CASCADE,
  content    TEXT NOT NULL,
  image_url  TEXT,
  like_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS comments_post_id_idx ON post_comments (post_id);


-- ────────────────────────────────────────
-- STEP 9. 좋아요 (게시글 / 댓글)
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS post_likes (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id    UUID REFERENCES posts(id) ON DELETE CASCADE,
  user_id    UUID REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (post_id, user_id)
);

CREATE TABLE IF NOT EXISTS comment_likes (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  comment_id UUID REFERENCES post_comments(id) ON DELETE CASCADE,
  user_id    UUID REFERENCES profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (comment_id, user_id)
);


-- ────────────────────────────────────────
-- STEP 10. 드로우 이벤트
-- (맥도날드 세트 같은 경품 추첨)
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS draws (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title                TEXT NOT NULL,     -- 맥도날드 빅맥 세트
  image_url            TEXT,
  coin_cost            INT NOT NULL,      -- 응모 코인 (170코인)
  max_entries_per_user INT DEFAULT 5,     -- 1인 최대 응모 횟수
  winner_count         INT DEFAULT 2,     -- 당첨자 수
  starts_at            TIMESTAMPTZ NOT NULL,
  ends_at              TIMESTAMPTZ NOT NULL,
  is_active            BOOLEAN DEFAULT TRUE,
  created_at           TIMESTAMPTZ DEFAULT NOW()
);


-- ────────────────────────────────────────
-- STEP 11. 드로우 참여 내역
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS draw_entries (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  draw_id     UUID REFERENCES draws(id) ON DELETE CASCADE,
  user_id     UUID REFERENCES profiles(id) ON DELETE CASCADE,
  entry_count INT DEFAULT 1,           -- 누적 응모 횟수
  is_winner   BOOLEAN DEFAULT FALSE,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (draw_id, user_id)
);


-- ────────────────────────────────────────
-- STEP 12. 코인 트랜잭션
-- (모든 코인 적립/사용 기록)
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS coin_transactions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES profiles(id) ON DELETE CASCADE,
  amount      INT NOT NULL,   -- 양수: 적립 / 음수: 사용
  type        TEXT CHECK (type IN (
                'scan',        -- 영수증 스캔 +10
                'attendance',  -- 출석 체크 +5
                'ad',          -- 광고 시청 +200
                'referral',    -- 친구 초대 +2000
                'draw',        -- 드로우 응모 -170
                'shop',        -- 상점 교환 (음수)
                'boost',       -- 만보기 부스트
                'bonus'        -- 기타 보너스
              )),
  description TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS coin_tx_user_id_idx ON coin_transactions (user_id, created_at DESC);


-- ────────────────────────────────────────
-- STEP 13. 출석 체크
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS attendance (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID REFERENCES profiles(id) ON DELETE CASCADE,
  date       DATE NOT NULL DEFAULT CURRENT_DATE,
  streak     INT  DEFAULT 1,   -- 연속 출석 일수
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (user_id, date)
);


-- ────────────────────────────────────────
-- STEP 14. 광고 미션 기록
-- (쿨다운 관리 / 하루 최대 3회)
-- ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ad_missions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID REFERENCES profiles(id) ON DELETE CASCADE,
  date            DATE NOT NULL DEFAULT CURRENT_DATE,
  count           INT  DEFAULT 0,    -- 오늘 시청 횟수
  last_watched_at TIMESTAMPTZ,       -- 쿨다운 계산용
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (user_id, date)
);


-- ────────────────────────────────────────
-- STEP 15. RLS (Row Level Security) 설정
-- (내 데이터는 내가, 공개 데이터는 모두가 볼 수 있게)
-- ────────────────────────────────────────

ALTER TABLE profiles          ENABLE ROW LEVEL SECURITY;
ALTER TABLE stores            ENABLE ROW LEVEL SECURITY;
ALTER TABLE price_pins        ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_reactions   ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_bookmarks   ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts             ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_comments     ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_likes        ENABLE ROW LEVEL SECURITY;
ALTER TABLE comment_likes     ENABLE ROW LEVEL SECURITY;
ALTER TABLE draws             ENABLE ROW LEVEL SECURITY;
ALTER TABLE draw_entries      ENABLE ROW LEVEL SECURITY;
ALTER TABLE coin_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance        ENABLE ROW LEVEL SECURITY;
ALTER TABLE ad_missions       ENABLE ROW LEVEL SECURITY;

-- profiles: 내 프로필만 수정, 전체 열람 가능
CREATE POLICY "profiles_read_all"   ON profiles FOR SELECT USING (true);
CREATE POLICY "profiles_write_own"  ON profiles FOR ALL    USING (auth.uid() = id);

-- stores: 전체 열람 가능, 로그인 유저만 등록
CREATE POLICY "stores_read_all"     ON stores FOR SELECT USING (true);
CREATE POLICY "stores_insert_auth"  ON stores FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- price_pins: 전체 열람, 내 핀만 삭제
CREATE POLICY "pins_read_all"       ON price_pins FOR SELECT USING (true);
CREATE POLICY "pins_insert_auth"    ON price_pins FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "pins_delete_own"     ON price_pins FOR DELETE USING (auth.uid() = user_id);

-- store_reactions: 전체 열람, 내 반응만 관리
CREATE POLICY "reactions_read_all"  ON store_reactions FOR SELECT USING (true);
CREATE POLICY "reactions_own"       ON store_reactions FOR ALL USING (auth.uid() = user_id);

-- store_bookmarks: 내 찜만 열람/관리
CREATE POLICY "bookmarks_own"       ON store_bookmarks FOR ALL USING (auth.uid() = user_id);

-- posts: 전체 열람, 내 글만 수정/삭제
CREATE POLICY "posts_read_all"      ON posts FOR SELECT USING (true);
CREATE POLICY "posts_insert_auth"   ON posts FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "posts_own"           ON posts FOR ALL USING (auth.uid() = user_id);

-- post_comments: 전체 열람, 내 댓글만 관리
CREATE POLICY "comments_read_all"   ON post_comments FOR SELECT USING (true);
CREATE POLICY "comments_insert_auth" ON post_comments FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "comments_own"        ON post_comments FOR ALL USING (auth.uid() = user_id);

-- post_likes / comment_likes
CREATE POLICY "post_likes_read_all" ON post_likes FOR SELECT USING (true);
CREATE POLICY "post_likes_own"      ON post_likes FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "comment_likes_read"  ON comment_likes FOR SELECT USING (true);
CREATE POLICY "comment_likes_own"   ON comment_likes FOR ALL USING (auth.uid() = user_id);

-- draws: 전체 열람
CREATE POLICY "draws_read_all"      ON draws FOR SELECT USING (true);

-- draw_entries: 내 참여 내역만
CREATE POLICY "entries_own"         ON draw_entries FOR ALL USING (auth.uid() = user_id);

-- coin_transactions: 내 코인만
CREATE POLICY "coins_own"           ON coin_transactions FOR ALL USING (auth.uid() = user_id);

-- attendance / ad_missions: 내 것만
CREATE POLICY "attendance_own"      ON attendance  FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "ad_missions_own"     ON ad_missions FOR ALL USING (auth.uid() = user_id);


-- ────────────────────────────────────────
-- STEP 16. 코인 적립 함수
-- (안전하게 코인 증감 처리)
-- ────────────────────────────────────────
CREATE OR REPLACE FUNCTION add_coins(
  p_user_id UUID,
  p_amount   INT,
  p_type     TEXT,
  p_desc     TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
  -- 코인 잔액 업데이트
  UPDATE profiles
  SET coin_balance = coin_balance + p_amount
  WHERE id = p_user_id;

  -- 트랜잭션 기록
  INSERT INTO coin_transactions (user_id, amount, type, description)
  VALUES (p_user_id, p_amount, p_type, p_desc);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ────────────────────────────────────────
-- STEP 17. 테스트 드로우 데이터 삽입
-- ────────────────────────────────────────
INSERT INTO draws (title, coin_cost, winner_count, starts_at, ends_at)
VALUES
  ('マクドナルド ビッグマックセット', 170, 2,
   NOW(), NOW() + INTERVAL '1 day'),
  ('スターバックス ドリンク券', 300, 1,
   NOW(), NOW() + INTERVAL '3 days')
ON CONFLICT DO NOTHING;


-- ============================================================
-- 완료! Supabase SQL Editor에서 실행하세요.
-- 기존 receipts, items 테이블은 유지됩니다.
-- ============================================================
