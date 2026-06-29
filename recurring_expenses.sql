-- build 582 — 정기지출(고정비) 자동 기록
-- 등록한 구독·월세·통신비 등을 매월 지정일에 가계부(receipts)로 자동 생성.
-- 생성 자체는 클라이언트가 앱 로드 시 idempotent 하게 수행(last_generated 기준).

create table if not exists public.recurring_expenses (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id) on delete cascade,
  name            text not null,
  amount          integer not null check (amount >= 0),
  category        text not null default 'fixed',
  payment_method  text,
  day_of_month    smallint not null check (day_of_month between 1 and 31),
  active          boolean not null default true,
  last_generated  date,                       -- 마지막으로 영수증 생성한 발생일(YYYY-MM-DD)
  created_at      timestamptz not null default now()
);

create index if not exists recurring_expenses_user_idx on public.recurring_expenses(user_id);

alter table public.recurring_expenses enable row level security;

-- 본인 행만 읽기/쓰기 (이미 있으면 무시)
do $$
begin
  if not exists (select 1 from pg_policies where tablename='recurring_expenses' and policyname='recurring_own_all') then
    create policy recurring_own_all on public.recurring_expenses
      for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
  end if;
end $$;
