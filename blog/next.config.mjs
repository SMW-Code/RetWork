/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  images: {
    remotePatterns: [
      { protocol: 'https', hostname: 'fkvfbxfgidrvymoftkdd.supabase.co' },
      { protocol: 'https', hostname: 'retwork.jp' },
    ],
  },
};
export default nextConfig;
