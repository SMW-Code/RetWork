-- 치리카드(메뉴카드)별 통화 (¥/₩) — build 662
-- 각 메뉴카드가 자신의 통화를 기억. 치리공개=영수증 통화, 수동핀=유저 설정 통화로 저장.
-- ⚠️ nullable(기본 NULL): 기존(미태깅) 카드는 NULL → 클라이언트가 표시/필터 시 'JPY'로 귀속
--    (앱이 일본 우선이라 과거 카드 대다수가 엔화). 'JPY' 강제 UPDATE는 하지 않음.
alter table public.store_menu_cards add column if not exists currency text;

-- 내 카드 탭 통화 필터 성능용(선택)
create index if not exists idx_smc_createdby_currency on public.store_menu_cards(created_by, currency);
