import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  async headers() {
    return [
      {
        // sw.js, index.html 절대 캐시 금지 — 항상 최신 버전 서빙
        source: "/(sw\\.js|index\\.html)",
        headers: [
          { key: "Cache-Control", value: "no-store, no-cache, must-revalidate, max-age=0" },
          { key: "Pragma",        value: "no-cache" },
          { key: "Expires",       value: "0" },
        ],
      },
      {
        // TWA Digital Asset Links — Chrome 이 정확한 Content-Type 으로 검증
        source: "/.well-known/assetlinks.json",
        headers: [
          { key: "Content-Type",  value: "application/json" },
          { key: "Cache-Control", value: "public, max-age=86400" },
        ],
      },
    ];
  },
};

export default nextConfig;
