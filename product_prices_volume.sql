-- ════════════════════════════════════════════════════════════════════════════
-- 절약 분석 용량 단가 비교 — product_aliases / product_prices 에 용량 컬럼 추가  b503
--
--   목적: 같은 상품이라도 사이즈(1L vs 500ml)가 다르면 단순 가격 비교가 왜곡됨.
--         상품 표기(=사이즈)별 용량을 저장 → ¥/100ml·g·個 단가로 공정 비교.
--   - qty_base : 기준수량(ml/g/개수로 정규화한 숫자).  l→×1000ml, kg→×1000g
--   - qty_kind : 'ml' | 'g' | 'ct'(개수)
--
--   product_aliases : 영수증 표기별(사이즈별) 용량 (raw_text 단위) — 클라가 GPT 표준화 시 채움
--   product_prices  : 그 가격 관측의 용량 (단가 비교용)
--   ⚠️ product_aliases, product_prices 테이블 선행. Supabase SQL Editor 에서 실행.
-- ════════════════════════════════════════════════════════════════════════════

alter table public.product_aliases add column if not exists qty_base numeric;
alter table public.product_aliases add column if not exists qty_kind text;

alter table public.product_prices  add column if not exists qty_base numeric;
alter table public.product_prices  add column if not exists qty_kind text;

-- (선택) 단가 비교 가속 인덱스
create index if not exists ppx_pid_kind_idx on public.product_prices(product_id, qty_kind);

-- 검증:
--   select raw_text, qty_base, qty_kind from public.product_aliases where qty_base is not null limit 20;
--   select store_name, price, qty_base, qty_kind from public.product_prices where qty_base is not null limit 20;
