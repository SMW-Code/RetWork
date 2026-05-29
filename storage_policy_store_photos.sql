-- ════════════════════════════════════════════════════════════════════════════
-- store-photos 버킷 Storage 정책 — 로컬 광고/상품 이미지 업로드 허용
--
-- 증상: 어드민 "로컬 광고 등록" 에서 "이미지 업로드 실패"
-- 원인(추정): store-photos 버킷에 INSERT(업로드) 정책이 없거나, 폴더(uid)
--             기준으로만 허용되어 'store-items/' 경로 업로드가 막힘.
--
-- 아래를 Supabase SQL Editor 에 붙여넣고 RUN.
-- (이미 같은 이름 정책이 있으면 DROP 후 재생성 → 중복 에러 방지)
-- ════════════════════════════════════════════════════════════════════════════

-- 0) 버킷이 없으면 생성 (public 읽기)
INSERT INTO storage.buckets (id, name, public)
VALUES ('store-photos', 'store-photos', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 1) 누구나 읽기 (이미지 표시용)
DROP POLICY IF EXISTS "store_photos_public_read" ON storage.objects;
CREATE POLICY "store_photos_public_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'store-photos');

-- 2) 로그인 사용자 업로드 허용
DROP POLICY IF EXISTS "store_photos_auth_insert" ON storage.objects;
CREATE POLICY "store_photos_auth_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'store-photos');

-- 3) 로그인 사용자 갱신 허용 (upsert/덮어쓰기)
DROP POLICY IF EXISTS "store_photos_auth_update" ON storage.objects;
CREATE POLICY "store_photos_auth_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'store-photos')
  WITH CHECK (bucket_id = 'store-photos');

-- 4) 어드민 삭제 허용 (선택)
DROP POLICY IF EXISTS "store_photos_admin_delete" ON storage.objects;
CREATE POLICY "store_photos_admin_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'store-photos'
    AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_admin = TRUE)
  );

-- 검증
-- SELECT policyname, cmd FROM pg_policies WHERE schemaname='storage' AND tablename='objects';
