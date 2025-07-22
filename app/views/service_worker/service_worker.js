importScripts("https://storage.googleapis.com/workbox-cdn/releases/6.5.4/workbox-sw.js");

const OFFLINE_URL   = 'offline.html';     // relativo -> /ventas/offline.html
const PRECACHE_URLS = [OFFLINE_URL, 'manifest.json']; // relativo -> /ventas/manifest.json


workbox.precaching.precacheAndRoute(PRECACHE_URLS, { ignoreURLParametersMatching: [/./] });

// Páginas HTML: NetworkFirst
workbox.routing.registerRoute(
    ({request}) => request.destination === 'document',
    new workbox.strategies.NetworkFirst({ cacheName: 'ventas-pages' })
);

// JS/CSS/Fonts: StaleWhileRevalidate
workbox.routing.registerRoute(
    ({request}) => ['script','style','font'].includes(request.destination),
    new workbox.strategies.StaleWhileRevalidate({ cacheName: 'ventas-static' })
);

// Imágenes: CacheFirst
workbox.routing.registerRoute(
    ({request}) => request.destination === 'image',
    new workbox.strategies.CacheFirst({ cacheName: 'ventas-images' })
);

// Warm cache + fallback offline
workbox.recipes.warmStrategyCache({
    urls: [OFFLINE_URL],
    strategy: new workbox.strategies.CacheFirst({ cacheName: 'ventas-pages' })
});

workbox.routing.setCatchHandler(async ({event}) => {
    if (event.request.destination === 'document') {
        return caches.match(OFFLINE_URL);
    }
    return Response.error();
});

// Logs opcionales:
self.addEventListener('install', e => console.log('[SW] install', e));
self.addEventListener('activate', e => console.log('[SW] activate', e));
self.addEventListener('fetch', e => {/* opcional */});
