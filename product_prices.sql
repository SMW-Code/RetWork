-- ════════════════════════════════════════════════════════════════════════════
-- product_prices — 커뮤니티 상품 가격 풀 (위치기반 「節約チャンス」 분석의 원천)  b498 / Phase 1
--
--   목적: 유저가 영수증을 찍으면 각 식료품의 (정규화상품 product_id · 가게 · 단가 · 좌표)를
--         공개 테이블에 익명 집계 → 다른 유저가 "내 근처 같은 상품 최저가"와 비교해 절약 가능액을 확인.
--   - 읽기: 전체 공개 (커뮤니티 가격 비교)
--   - 쓰기/수정: 본인 행만 (user_id = auth.uid())
--   - 유저당 (상품, 가게) 1행 = 그 유저가 그 가게에서 산 최신 단가 (upsert)
--
--   ⚠️ products_master 테이블(상품 정규화)이 선행되어야 함(이미 존재). Supabase SQL Editor 에서 실행.
-- ════════════════════════════════════════════════════════════════════════════

create table if not exists public.product_prices (
  id          uuid primary key default gen_random_uuid(),
  product_id  uuid not null references public.products_master(id) on delete cascade,
  store_name  text not null,
  price       integer not null,                 -- 단가(¥, 정수)
  lat         double precision,                 -- 가게 좌표(있으면 위치 필터에 사용)
  lng         double precision,
  category    text,
  user_id     uuid references auth.users(id) on delete cascade,
  updated_at  timestamptz not null default now(),
  unique (product_id, store_name, user_id)      -- 유저당 (상품,가게) 1행
);

alter table public.product_prices enable row level security;

-- 읽기: 전체 공개
drop policy if exists "ppx_read_all" on public.product_prices;
create policy "ppx_read_all" on public.product_prices
  for select using (true);

-- 추가: 본인 user_id 로만
drop policy if exists "ppx_insert_own" on public.product_prices;
create policy "ppx_insert_own" on public.product_prices
  for insert with check (auth.uid() = user_id);

-- 수정: 본인 행만
drop policy if exists "ppx_update_own" on public.product_prices;
create policy "ppx_update_own" on public.product_prices
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- 삭제: 본인 행만 (선택)
drop policy if exists "ppx_delete_own" on public.product_prices;
create policy "ppx_delete_own" on public.product_prices
  for delete using (auth.uid() = user_id);

create index if not exists ppx_product_idx on public.product_prices(product_id);
create index if not exists ppx_geo_idx     on public.product_prices(lat, lng);

-- ════════════════════════════════════════════════════════════════════════════
-- 검증:
--   select count(*) from public.product_prices;
--   select pm.canonical, pp.store_name, pp.price, pp.lat, pp.lng
--   from public.product_prices pp join public.products_master pm on pm.id = pp.product_id
--   order by pp.updated_at desc limit 20;
-- ════════════════════════════════════════════════════════════════════════════
