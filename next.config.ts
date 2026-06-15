import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // b488 — 루트(/)를 정적 PWA(public/index.html)로 내부 rewrite(200, URL 그대로 유지).
  //   기존 redirect(307)는 / 를 비콘텐츠 URL로 만들어 Google이 색인 못함 + canonical 충돌
  //   (Google이 사용자 선언 /index.html 을 무시하고 / 를 표준으로 재선택). rewrite 로
  //   / 가 실제 200 콘텐츠를 서빙 → canonical=/ 와 일치해 / 가 정상 색인됨.
  //   ?ref= 등 쿼리는 URL 그대로 유지되어 클라이언트 head 스크립트가 캡처(리다이렉트 불필요).
  //   beforeFiles 라서 app/page.tsx(/) 보다 먼저 적용(=페이지 파일 오버라이드). page.tsx 는
  //   rewrite 미스 시 폴백(ref 보존 리다이렉트)으로 남겨둠.
  async rewrites() {
    return {
      beforeFiles: [{ source: "/", destination: "/index.html" }],
    };
  },
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
        // 루트(/) — rewrite 로 index.html 을 서빙하므로 동일하게 캐시 금지(스테일 방지)
        source: "/",
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
