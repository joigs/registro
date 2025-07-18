const CACHE_NAME   = 'ventas-pwa-v3';
const OFFLINE_PAGE = 'offline.html';
const MANIFEST_URL = 'manifest.json';

// Recursos estables (relativos al sub-path)
const PRECACHE_URLS = [
    OFFLINE_PAGE,
    MANIFEST_URL
];

self.addEventListener('install', event => {
    event.waitUntil((async () => {
        const cache = await caches.open(CACHE_NAME);
        for (const url of PRECACHE_URLS) {
            try {
                const res = await fetch(url, { credentials: 'same-origin' });
                if (res.ok) await cache.put(url, res);
            } catch (e) {
                console.warn('[SW] No precache', url, e);
            }
        }
        await self.skipWaiting();
    })());
});

self.addEventListener('activate', event => {
    event.waitUntil(
        caches.keys()
            .then(keys => Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k))))
            .then(() => self.clients.claim())
    );
});

self.addEventListener('fetch', event => {
    const req = event.request;
    if (req.method !== 'GET') return;

    event.respondWith((async () => {
        try {
            const netRes = await fetch(req);
            if (
                netRes.ok &&
                req.url.startsWith(self.location.origin) &&
                ['script', 'style', 'image', 'font'].includes(req.destination)
            ) {
                const cache = await caches.open(CACHE_NAME);
                cache.put(req, netRes.clone());
            }
            return netRes;
        } catch (e) {
            const cached = await caches.match(req);
            if (cached) return cached;

            if (req.mode === 'navigate') {
                const offline = await caches.match(OFFLINE_PAGE);
                if (offline) return offline;
            }

            return new Response('Offline', { status: 503, statusText: 'Offline' });
        }
    })());
});
