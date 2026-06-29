-- build 584 — 카테고리별 예산 클라우드 동기화
-- profiles 에 cat_budgets(jsonb) 추가. {"food":30000,"eat":20000,...} 형태.
-- 미실행이어도 앱은 동작(로컬 저장만) → 실행하면 기기 간 동기화.

alter table public.profiles
  add column if not exists cat_budgets jsonb;
