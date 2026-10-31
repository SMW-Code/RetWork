-- 영수증별 통화 (B: ¥/₩ 혼용) — build 656
-- 각 영수증이 자신의 통화를 기억. 기존 영수증은 전부 JPY (하위호환).
alter table public.receipts add column if not exists currency text not null default 'JPY';

-- 통화별 집계/필터 성능용(선택)
create index if not exists idx_receipts_user_currency on public.receipts(user_id, currency);
