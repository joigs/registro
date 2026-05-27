import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
    connect() {
        if (!("serviceWorker" in navigator)) return;
        if (!location.pathname.startsWith("/ventas/fotos_melon/admin/")) return;

        navigator.serviceWorker
            .register("/ventas/fotos_melon/admin/service-worker.js", {
                scope: "/ventas/fotos_melon/admin/"
            })
            .then((reg) => {
                console.log("[FotosMelon Admin] Service worker registrado, scope:", reg.scope);
            })
            .catch((err) => {
                console.error("[FotosMelon Admin] Falló registro de SW:", err);
            });
    }
}