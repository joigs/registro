const CACHE_NAME = 'ventas-pwa-v2';
const OFFLINE_URL = '/offline.html';

self.addEventListener('install', event => {
    event.waitUntil((async () => {
        const cache = await caches.open(CACHE_NAME);
        for (const url of ['/', OFFLINE_URL, '/manifest.json']) {
            try {
                const r = await fetch(url);
                if (r.ok) await cache.put(url, r);
            } catch(e) { console.warn('No precache', url); }
        }
        await self.skipWaiting();
    })());
});

self.addEventListener('activate', event => {
    event.waitUntil(
        caches.keys().then(keys =>
            Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))
        ).then(() => self.clients.claim())
    );
});

self.addEventListener('fetch', event => {
    const req = event.request;
    if (req.method !== 'GET') return;

    event.respondWith((async () => {
        try {
            const netRes = await fetch(req);
            if (netRes.ok && req.url.startsWith(self.location.origin) &&
                ['script','style','image','font'].includes(req.destination)) {
                const cache = await caches.open(CACHE_NAME);
                cache.put(req, netRes.clone());
            }
            return netRes;
        } catch(e) {
            const cacheMatch = await caches.match(req);
            if (cacheMatch) return cacheMatch;
            if (req.mode === 'navigate') {
                const offline = await caches.match(OFFLINE_URL);
                if (offline) return offline;
            }
            return new Response('Offline', { status: 503, statusText: 'Offline' });
        }
    })());
});
