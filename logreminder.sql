-- build 583 — 기록 리마인더 옵트인
-- push_subscriptions 에 logreminder_optin 컬럼 추가 (attendance_optin / pricewatch_optin 와 동일 패턴).
-- 미실행이어도 앱은 동작(토글 저장만 실패) → 실행하면 저녁 푸시 리마인더 활성.

alter table public.push_subscriptions
  add column if not exists logreminder_optin boolean not null default false;
