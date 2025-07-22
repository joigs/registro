// app/javascript/custom/companion.js
if (navigator.serviceWorker && location.pathname.startsWith('/ventas/')) {
    navigator.serviceWorker
        .register("/ventas/service-worker.js?v=10", { scope: "/ventas/" })
        .then(() => navigator.serviceWorker.ready)
        .then(registration => {
            if ("SyncManager" in window) {
                registration.sync.register("sync-forms");
            } else {
                console.log("This browser does not support background sync.");
            }
        })
        .then(() => console.log("[Companion]", "Service worker registered!"));
}
