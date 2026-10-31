-- 영수증별 통화 (B: ¥/₩ 혼용) — build 656
-- 각 영수증이 자신의 통화를 기억. 신규 스캔은 명시 저장(JPY/KRW).
-- ⚠️ nullable(기본 NULL)로 둔다: 기존(미태깅) 영수증은 NULL → 클라이언트가 로드 시
--    유저의 현재 통화 설정값으로 귀속(한국유저=₩, 일본유저=¥). 'JPY' 강제 금지.
alter table public.receipts add column if not exists currency text;

-- 통화별 집계/필터 성능용(선택)
create index if not exists idx_receipts_user_currency on public.receipts(user_id, currency);
