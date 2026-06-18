-- ════════════════════════════════════════════════════════════════════════════
-- 가격 변동 알림 (price watch + push) — Phase 1  b531
--
--   목적: 자주 사는 상품이 "내 동네(앵커 = 내 product_prices 좌표 중심) 반경 내"에서
--         더 싸게 풀리면, 앱이 꺼져 있어도 Web Push 로 알림.
--   동작 원천: 서버 크론(/api/cron/price-watch) 이 product_prices(전체공개)를 스캔.
--             "내가 산 것" = product_prices.user_id = 나. (영수증 join 불필요)
--
--   추가물:
--   1) push_subscriptions.pricewatch_optin — 가격 알림 옵트인 (attendance_optin 패턴)
--   2) price_alerts_sent — 같은 알림 도배 방지(쿨다운). 유저×상품×가게 1행, sent_at 갱신
--
--   ⚠️ product_prices / push_subscriptions 선행. Supabase SQL Editor 에서 실행.
-- ════════════════════════════════════════════════════════════════════════════

alter table public.push_subscriptions add column if not exists pricewatch_optin boolean default false;

create table if not exists public.price_alerts_sent (
  id          bigserial primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  product_id  uuid not null,
  store_name  text not null,
  price       integer,
  body        text,                                 -- 인앱 알림함 표시용 메시지(푸시 본문과 동일)
  sent_at     timestamptz not null default now(),
  unique (user_id, product_id, store_name)
);
-- 기존 테이블이 이미 있던 경우 대비
alter table public.price_alerts_sent add column if not exists body text;

create index if not exists pas_user_sent_idx on public.price_alerts_sent(user_id, sent_at);

-- RLS: 서버(service_role)만 쓰므로 정책 없이 RLS on (클라 접근 차단). 본인 읽기만 허용(선택).
alter table public.price_alerts_sent enable row level security;
drop policy if exists "pas_read_own" on public.price_alerts_sent;
create policy "pas_read_own" on public.price_alerts_sent
  for select using (auth.uid() = user_id);

-- 검증:
--   select column_name from information_schema.columns where table_name='push_subscriptions' and column_name='pricewatch_optin';
--   select count(*) from public.price_alerts_sent;
