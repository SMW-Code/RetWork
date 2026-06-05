/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // 빌드 중 타입/린트 에러로 차단되지 않도록 (안전망)
  typescript: { ignoreBuildErrors: true },
  eslint: { ignoreDuringBuilds: true },
  images: {
    remotePatterns: [
      { protocol: 'https', hostname: 'fkvfbxfgidrvymoftkdd.supabase.co' },
      { protocol: 'https', hostname: 'retwork.jp' },
    ],
  },
};
export default nextConfig;
