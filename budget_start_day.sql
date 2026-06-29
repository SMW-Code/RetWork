-- build 575 — 월 시작일(급여 주기) 설정 클라우드 동기화용 컬럼
-- 미실행이어도 앱은 동작함(localStorage 로컬 저장). 실행하면 기기 간 동기화됨.
-- profiles 테이블에 budget_start_day(1~28, 기본 1) 추가.

alter table public.profiles
  add column if not exists budget_start_day smallint;

-- (선택) 값 범위 제약 — 1~28 만 허용. 이미 있으면 무시.
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'profiles_budget_start_day_chk'
  ) then
    alter table public.profiles
      add constraint profiles_budget_start_day_chk
      check (budget_start_day is null or (budget_start_day >= 1 and budget_start_day <= 28));
  end if;
end $$;

-- RLS: profiles 는 이미 본인 행 update 정책이 있으므로 추가 정책 불필요.
-- 기존 budget_amount/budget_month 와 동일 경로로 본인만 읽기/쓰기.
