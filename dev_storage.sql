-- ════════════════════════════════════════════════════════════════════════════
-- dev Supabase 스토리지 복제 — prod에서 추출한 버킷 + storage.objects RLS 정책
--
--   대상: RetWork-dev (ljxkqxjhrahzvnodqlqt)
--   실행: dev Supabase SQL Editor 에서 (RLS 경고 뜨면 "Run without RLS" — 이미 켜져 있음)
--   idempotent: 여러 번 돌려도 안전
-- ════════════════════════════════════════════════════════════════════════════

-- 1) 버킷 3개 ----------------------------------------------------------------
INSERT INTO storage.buckets (id,name,public) VALUES ('ct-post-images','ct-post-images',true)  ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id,name,public) VALUES ('store-photos','store-photos',true)       ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id,name,public) VALUES ('receipt-images','receipt-images',false)  ON CONFLICT (id) DO NOTHING;

-- 2) storage.objects RLS 정책 -------------------------------------------------
-- ct-post-images (치리톡 게시글 이미지) -----------------------------
DROP POLICY IF EXISTS "auth_upload 11z3pwp_0" ON storage.objects;
CREATE POLICY "auth_upload 11z3pwp_0" ON storage.objects FOR INSERT TO public WITH CHECK ((bucket_id = 'ct-post-images'::text));

DROP POLICY IF EXISTS "public_read 11z3pwp_0" ON storage.objects;
CREATE POLICY "public_read 11z3pwp_0" ON storage.objects FOR SELECT TO public USING ((bucket_id = 'ct-post-images'::text));

-- receipt-images (영수증 원본 — 비공개, 본인+어드민만) --------------
DROP POLICY IF EXISTS receipt_img_insert_own ON storage.objects;
CREATE POLICY receipt_img_insert_own ON storage.objects FOR INSERT TO authenticated WITH CHECK (((bucket_id = 'receipt-images'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));

DROP POLICY IF EXISTS receipt_img_select_own_admin ON storage.objects;
CREATE POLICY receipt_img_select_own_admin ON storage.objects FOR SELECT TO authenticated USING (((bucket_id = 'receipt-images'::text) AND (((storage.foldername(name))[1] = (auth.uid())::text) OR (EXISTS ( SELECT 1 FROM profiles WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))))));

DROP POLICY IF EXISTS receipt_img_delete_own_admin ON storage.objects;
CREATE POLICY receipt_img_delete_own_admin ON storage.objects FOR DELETE TO authenticated USING (((bucket_id = 'receipt-images'::text) AND (((storage.foldername(name))[1] = (auth.uid())::text) OR (EXISTS ( SELECT 1 FROM profiles WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true)))))));

-- store-photos (가게 사진 — 공개 읽기, 로그인 업로드) ----------------
DROP POLICY IF EXISTS store_photos_public_read ON storage.objects;
CREATE POLICY store_photos_public_read ON storage.objects FOR SELECT TO public USING ((bucket_id = 'store-photos'::text));

DROP POLICY IF EXISTS store_photos_read ON storage.objects;
CREATE POLICY store_photos_read ON storage.objects FOR SELECT TO public USING ((bucket_id = 'store-photos'::text));

DROP POLICY IF EXISTS store_photos_auth_insert ON storage.objects;
CREATE POLICY store_photos_auth_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK ((bucket_id = 'store-photos'::text));

DROP POLICY IF EXISTS store_photos_upload ON storage.objects;
CREATE POLICY store_photos_upload ON storage.objects FOR INSERT TO public WITH CHECK (((bucket_id = 'store-photos'::text) AND (auth.uid() IS NOT NULL) AND ((storage.foldername(name))[1] = (auth.uid())::text)));

DROP POLICY IF EXISTS store_photos_auth_update ON storage.objects;
CREATE POLICY store_photos_auth_update ON storage.objects FOR UPDATE TO authenticated USING ((bucket_id = 'store-photos'::text)) WITH CHECK ((bucket_id = 'store-photos'::text));

DROP POLICY IF EXISTS store_photos_admin_delete ON storage.objects;
CREATE POLICY store_photos_admin_delete ON storage.objects FOR DELETE TO authenticated USING (((bucket_id = 'store-photos'::text) AND (EXISTS ( SELECT 1 FROM profiles WHERE ((profiles.id = auth.uid()) AND (profiles.is_admin = true))))));

-- ════════════════════════════════════════════════════════════════════════════
-- 검증:
--   SELECT id, public FROM storage.buckets ORDER BY id;
--   SELECT policyname FROM pg_policies WHERE schemaname='storage' AND tablename='objects' ORDER BY policyname;
-- ════════════════════════════════════════════════════════════════════════════
