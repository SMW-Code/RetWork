-- ════════════════════════════════════════════════════════════════════════════
-- 홈 명언 카드 — 정적 시드 데이터 (코드 내장 _QUOTES_BY_LANG 48개 이식)
--
--   먼저 quotes.sql 실행 후 이 파일 실행.
--   ON CONFLICT DO NOTHING 으로 중복 INSERT 방지 (lang+text unique constraint 가 없으므로
--   기존 데이터 있어도 추가될 수 있음 → 빈 quotes 테이블에 1회만 실행 권장).
--
--   ja/ko/en/zh 각 12개 = 총 48개
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- ja (日本語) 12개
INSERT INTO quotes (lang, text, sort_order) VALUES
  ('ja', '小さな節約が大きな富を生む',              12),
  ('ja', 'お金を使う前にもう一度考えよう',          11),
  ('ja', '富裕層はお金を使うより貯める',            10),
  ('ja', '今日の節約が明日の自由',                  9),
  ('ja', '必要なものと欲しいものを区別しよう',      8),
  ('ja', '毎日少しずつで人生が変わる',              7),
  ('ja', '買う前に本当に必要か問いかけよう',        6),
  ('ja', '貯金は未来の自分への贈り物',              5),
  ('ja', 'お金は感情でなく計画で使おう',            4),
  ('ja', '塵も積もれば山となる',                    3),
  ('ja', '無駄遣いをやめれば夢が近づく',            2),
  ('ja', '支出を知ることが節約の第一歩',            1);

-- ko (한국어) 12개
INSERT INTO quotes (lang, text, sort_order) VALUES
  ('ko', '작은 절약이 큰 부를 만든다',              12),
  ('ko', '돈을 쓰기 전에 한 번 더 생각하라',        11),
  ('ko', '부자는 돈을 쓰는 게 아니라 모은다',       10),
  ('ko', '오늘의 절약이 내일의 자유다',             9),
  ('ko', '필요한 것과 원하는 것을 구분하라',        8),
  ('ko', '매일 조금씩 아끼면 인생이 바뀐다',        7),
  ('ko', '소비하기 전 진짜 필요한지 물어봐라',      6),
  ('ko', '저축은 나중의 나를 위한 선물이다',        5),
  ('ko', '돈은 감정이 아닌 계획으로 써라',          4),
  ('ko', '티끌 모아 태산',                          3),
  ('ko', '낭비를 멈추면 꿈이 가까워진다',           2),
  ('ko', '지출을 아는 것이 절약의 첫걸음',          1);

-- en (English) 12개
INSERT INTO quotes (lang, text, sort_order) VALUES
  ('en', 'Small savings build great wealth',                12),
  ('en', 'Think twice before you spend',                    11),
  ('en', 'The rich save more than they spend',              10),
  ('en', 'Today''s saving is tomorrow''s freedom',           9),
  ('en', 'Tell needs apart from wants',                     8),
  ('en', 'Save a little daily, change your life',           7),
  ('en', 'Ask if you truly need it before buying',          6),
  ('en', 'Savings are a gift to future you',                5),
  ('en', 'Spend by plan, not by emotion',                   4),
  ('en', 'Many drops make an ocean',                        3),
  ('en', 'Cut waste and your dreams draw near',             2),
  ('en', 'Knowing your spending is step one',               1);

-- zh (中文) 12개
INSERT INTO quotes (lang, text, sort_order) VALUES
  ('zh', '积少成多，小钱成大富',                    12),
  ('zh', '花钱之前再想一想',                        11),
  ('zh', '富人不是花钱而是攒钱',                    10),
  ('zh', '今天的节约是明天的自由',                  9),
  ('zh', '分清需要和想要',                          8),
  ('zh', '每天省一点，人生会改变',                  7),
  ('zh', '购买前先问是否真的需要',                  6),
  ('zh', '储蓄是给未来自己的礼物',                  5),
  ('zh', '用计划而非情绪花钱',                      4),
  ('zh', '积土成山',                                3),
  ('zh', '停止浪费，梦想更近',                      2),
  ('zh', '了解支出是节约的第一步',                  1);

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
-- 검증
--   SELECT lang, count(*) FROM quotes GROUP BY lang;
--   → ja:12, ko:12, en:12, zh:12 (총 48개)
-- ════════════════════════════════════════════════════════════════════════════
