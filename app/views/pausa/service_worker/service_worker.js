/* pausa/service-worker.js  – scope: /pausa/  */
self.addEventListener("install", e => {
    console.log("[Pausa‑SW] install");
    self.skipWaiting();
});

self.addEventListener("activate", e => {
    console.log("[Pausa‑SW] activate");
});

self.addEventListener("fetch", e => {
    // ejemplo: cache‑first para iconos dentro de /pausa/
    if (e.request.destination === "image" &&
        e.request.url.includes("/pausa/")) {
        e.respondWith(
            caches.open("pausa-assets").then(cache =>
                cache.match(e.request).then(resp =>
                        resp || fetch(e.request).then(r => {
                            cache.put(e.request, r.clone());
                            return r;
                        })
                )
            )
        );
    }
});
