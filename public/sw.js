const CACHE_NAME = 'receiptiq-v0.9.0-b297';
// manifest.json은 인라인 Blob URL로 처리됨 (Vercel 방화벽 차단 회피)
const STATIC_CACHE = ['/icons/icon.png', '/icons/icon.svg'];

// 설치: 정적 파일만 프리캐시
self.addEventListener('install', event => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => cache.addAll(STATIC_CACHE))
  );
});

// 활성화: 구버전 캐시 전부 삭제
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
});

// 패치 전략:
//   index.html → 네트워크 우선 (항상 최신 버전)
//   나머지     → 캐시 우선 (빠른 로딩)
self.addEventListener('fetch', event => {
  if (!event.request.url.startsWith(self.location.origin)) return;
  if (event.request.method !== 'GET') return;

  const url = new URL(event.request.url);
  const isHTML = url.pathname === '/' || url.pathname.endsWith('.html');

  if (isHTML) {
    // HTML은 절대 캐시하지 않음 — 항상 네트워크에서 최신 버전 가져옴
    event.respondWith(
      fetch(event.request, { cache: 'no-store' })
        .catch(() => caches.match(event.request))
    );
  } else {
    // 캐시 우선: 없으면 네트워크 후 저장
    event.respondWith(
      caches.match(event.request).then(cached => {
        if (cached) return cached;
        return fetch(event.request).then(response => {
          if (response.ok) {
            const clone = response.clone();
            caches.open(CACHE_NAME).then(cache => cache.put(event.request, clone));
          }
          return response;
        });
      })
    );
  }
});
