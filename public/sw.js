const CACHE_NAME = 'receiptiq-v0.9.0-b404';
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

// ════════════════════════════════════════════════════════════════════════════
// build 306 — Web Push 알림 처리
//   서버(/api/push) → push 이벤트 → 시스템 알림 표시
//   사용자가 알림 탭 → notificationclick → 앱 열고 link 로 이동
// ════════════════════════════════════════════════════════════════════════════
self.addEventListener('push', event => {
  let payload = {};
  try {
    payload = event.data ? event.data.json() : {};
  } catch (e) {
    payload = { title: 'RetWork', body: event.data ? event.data.text() : '' };
  }
  const title = payload.title || 'RetWork';
  const priority = (payload.priority || 'normal').toString();
  const isUrgent = priority === 'urgent';
  const isHigh   = priority === 'high';

  const opts = {
    body:  payload.body || '',
    icon:  payload.icon  || '/icons/icon.png',
    badge: payload.badge || '/icons/icon.png',
    tag:   payload.tag   || 'retwork-msg',  // 같은 tag 면 알림 덮어쓰기 (스팸 방지)
    // build 310 — 헤즈업/배너 표시 강화
    renotify: true,                                 // build 312 — 항상 ON (모든 알림 새로 표시)
    requireInteraction: isUrgent,                  // urgent 면 사용자가 닫기 전까지 유지 (Android)
    silent: false,                                  // 소리/진동 ON
    vibrate: isUrgent ? [300, 100, 300, 100, 300]   // 긴급: 강하게
            : isHigh   ? [200, 100, 200]            // 높음: 보통
                       : [150],                     // 일반: 짧게
    timestamp: Date.now(),                          // build 312 — 최신 알림 표시
    image: payload.image || undefined,              // build 312 — 큰 이미지 있으면 Big Picture
    data: {
      url: payload.url || payload.link || '/',
      messageId: payload.messageId || null,
      priority: priority
    },
    // build 312 — 액션 버튼 2개 (Android 에서 rich notification 인식 → 헤즈업 우선)
    actions: payload.actions || [
      { action: 'open', title: '확인' },
      { action: 'dismiss', title: '닫기' }
    ]
  };
  event.waitUntil(self.registration.showNotification(title, opts));
});

self.addEventListener('notificationclick', event => {
  event.notification.close();
  // build 312 — 'dismiss' 액션은 알림만 닫고 앱 안 열기
  if (event.action === 'dismiss') return;
  const url = (event.notification.data && event.notification.data.url) || '/';
  // 이미 열린 앱 창이 있으면 focus, 없으면 새로 열기
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(clients => {
      for (const c of clients) {
        // 같은 origin 창이 이미 있으면 focus + navigate
        try {
          const cu = new URL(c.url);
          if (cu.origin === self.location.origin) {
            return c.focus().then(() => {
              if ('navigate' in c) c.navigate(url);
            });
          }
        } catch (e) {}
      }
      // 없으면 새 창
      return self.clients.openWindow(url);
    })
  );
});
