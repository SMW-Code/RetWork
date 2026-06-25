-- ════════════════════════════════════════════════════════════════════════════
-- client_redeem_item — 상품 교환 원자적 RPC (코인차감+재고차감+신청생성 = 1 트랜잭션)
--
-- 기존 문제(ctStoreExchangeDB):
--   - 코인 차감(ctAddCoin)이 fire-and-forget → 교환 신청/재고 차감과 분리됨
--   - client_add_coins 는 GREATEST(0, ...) 라 잔액보다 많이 차감해도 0으로 깎고 성공
--     → 서버측 잔액부족 검사가 없음 → "공짜 상품" / "코인만 날림" 사고 가능
--
-- 해결: 이 RPC 하나에서 행 잠금(FOR UPDATE) + 잔액 충분성 검사 + 코인차감 +
--       재고차감 + exchange_requests 생성을 전부 처리. 함수=단일 트랜잭션이라 원자적.
--
-- Supabase SQL Editor 에 그대로 붙여넣고 RUN. (CREATE OR REPLACE → 재실행 안전)
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

CREATE OR REPLACE FUNCTION client_redeem_item(p_item_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user   UUID := auth.uid();
  v_item   store_items%ROWTYPE;
  v_bal    INT;
  v_new    INT;
  v_email  TEXT;
  v_nick   TEXT;
  v_req_id UUID;
BEGIN
  IF v_user IS NULL THEN
    RETURN json_build_object('ok', false, 'err', 'not_logged_in');
  END IF;

  -- 1) 상품 행 잠금 조회 (동시 교환 시 재고 경쟁 방지)
  SELECT * INTO v_item
    FROM store_items
    WHERE id = p_item_id AND is_active = true
    FOR UPDATE;
  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'err', 'item_not_found');
  END IF;

  -- 2) 재고 확인 (0 = 품절 / >0 = 유한 / <0 = 무제한)
  IF v_item.stock = 0 THEN
    RETURN json_build_object('ok', false, 'err', 'out_of_stock');
  END IF;

  -- 3) 잔액 행 잠금 조회 + 충분성 검사 (서버가 권위 — 클라 잔액 신뢰 X)
  SELECT COALESCE(coin_balance, 0) INTO v_bal
    FROM profiles WHERE id = v_user
    FOR UPDATE;
  IF v_bal < v_item.cost_chiri THEN
    RETURN json_build_object('ok', false, 'err', 'insufficient',
                             'balance', v_bal, 'cost', v_item.cost_chiri);
  END IF;

  -- 4) 코인 차감 + 거래기록 (client_add_coins 와 동일하게 트리거 bypass)
  PERFORM set_config('app.admin_action', 'true', true);
  UPDATE profiles
    SET coin_balance = coin_balance - v_item.cost_chiri
    WHERE id = v_user
    RETURNING coin_balance INTO v_new;
  INSERT INTO coin_transactions(user_id, amount, type, description)
    VALUES (v_user, -v_item.cost_chiri, 'shop', '🎁 「' || v_item.name || '」交換');

  -- 5) 재고 차감 (유한 재고일 때만)
  IF v_item.stock > 0 THEN
    UPDATE store_items SET stock = stock - 1 WHERE id = v_item.id;
  END IF;

  -- 6) 사용자 스냅샷 (이메일/닉네임 — 운영 조회 편의)
  SELECT email    INTO v_email FROM auth.users WHERE id = v_user;
  SELECT nickname INTO v_nick  FROM profiles    WHERE id = v_user;

  -- 7) 교환 신청 생성
  INSERT INTO exchange_requests(
    user_id, item_id, item_name, item_image_url, cost_chiri,
    user_email, user_nickname, status
  ) VALUES (
    v_user, v_item.id, v_item.name, v_item.image_url, v_item.cost_chiri,
    v_email, v_nick, 'pending'
  ) RETURNING id INTO v_req_id;

  RETURN json_build_object('ok', true, 'balance', v_new,
                           'request_id', v_req_id, 'item_name', v_item.name);
END $$;

GRANT EXECUTE ON FUNCTION client_redeem_item(UUID) TO authenticated;

COMMIT;

-- ════════════════════════════════════════════════════════════════════════════
-- 검증 예시 (Supabase SQL Editor 에서, 본인 로그인 컨텍스트 아닐 땐 auth.uid()=null 이라
--           'not_logged_in' 정상. 실제 검증은 앱에서):
--   SELECT client_redeem_item('<store_items.id>');
-- 동작 확인 포인트:
--   - 잔액 부족 → {"ok":false,"err":"insufficient",...} 이고 coin_balance/재고/신청 변화 없음
--   - 정상      → {"ok":true,...} 이고 coin_balance 차감 + stock-1 + exchange_requests 1건
-- ════════════════════════════════════════════════════════════════════════════
