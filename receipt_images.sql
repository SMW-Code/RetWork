-- ════════════════════════════════════════════════════════════════════════════
-- 영수증 원본 이미지 보관 — receipts.image_url + receipt-images 버킷 + RLS
--
--   목적(베타): 운영자가 "유저가 올린 원본 영수증 ↔ AI 파싱 결과"를 비교해서
--   OCR 프롬프트를 개선. 압축 저장이라 용량 부담 적음. 비공개(본인+어드민만).
--
--   Supabase SQL Editor 에서 실행 (idempotent).
-- ════════════════════════════════════════════════════════════════════════════

BEGIN;

-- 1) 영수증에 원본 이미지 경로 컬럼 (storage 경로: <uid>/<receiptId>.jpg)
ALTER TABLE receipts ADD COLUMN IF NOT EXISTS image_url TEXT;

-- 2) 비공개 스토리지 버킷
INSERT INTO storage.buckets (id, name, public)
VALUES ('receipt-images', 'receipt-images', false)
ON CONFLICT (id) DO NOTHING;

COMMIT;

-- 3) 스토리지 RLS (storage.objects) — 본인 폴더만 업로드, 조회/삭제는 본인+어드민
DROP POLICY IF EXISTS receipt_img_insert_own       ON storage.objects;
DROP POLICY IF EXISTS receipt_img_select_own_admin ON storage.objects;
DROP POLICY IF EXISTS receipt_img_delete_own_admin ON storage.objects;

-- 업로드: 로그인 유저가 "자기 uid 폴더"에만
CREATE POLICY receipt_img_insert_own ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'receipt-images'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- 조회: 본인 영수증 이미지 + 어드민은 전부
CREATE POLICY receipt_img_select_own_admin ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'receipt-images'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
    )
  );

-- 삭제: 본인 + 어드민
CREATE POLICY receipt_img_delete_own_admin ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'receipt-images'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND is_admin = true)
    )
  );

-- ════════════════════════════════════════════════════════════════════════════
-- 검증
--   SELECT id, name FROM storage.buckets WHERE id = 'receipt-images';
--   SELECT id, store_name, image_url FROM receipts WHERE image_url IS NOT NULL LIMIT 5;
-- ════════════════════════════════════════════════════════════════════════════
