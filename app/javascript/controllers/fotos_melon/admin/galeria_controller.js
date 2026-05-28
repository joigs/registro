import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
    static targets = [
        "item", "check", "barraNormal", "barraSeleccion", "contador", "datos",
        "lightbox", "lightboxImg", "lightboxDescargar",
        "moverLista", "formEliminar", "formRenombrar", "formRenombrarInput",
        "formZip", "formZipIds", "formMover", "formMoverDestino"
    ];

    connect() {
        this.sel = new Set();
        this.cfg = JSON.parse(this.datosTarget.textContent);
        this.actualId = null;
    }

    clickItem(event) {
        const li = event.currentTarget;
        const id = parseInt(li.dataset.fotoId, 10);
        if (this.sel.size > 0) {
            this.toggle(id, li);
        } else {
            this.abrirLightbox(id);
        }
    }

    toggle(id, li) {
        const check = li.querySelector("[data-fotos-melon--admin--galeria-target='check']");
        if (this.sel.has(id)) {
            this.sel.delete(id);
            li.classList.remove("ring-2", "ring-fm-accent");
            check.classList.add("hidden"); check.classList.remove("flex", "bg-fm-accent");
        } else {
            this.sel.add(id);
            li.classList.add("ring-2", "ring-fm-accent");
            check.classList.remove("hidden"); check.classList.add("flex", "bg-fm-accent");
        }
        this.refrescarBarra();
    }

    refrescarBarra() {
        this.contadorTarget.textContent = this.sel.size;
        if (this.sel.size > 0) {
            this.barraNormalTarget.classList.add("hidden");
            this.barraSeleccionTarget.classList.remove("hidden");
            this.barraSeleccionTarget.classList.add("flex");
        } else {
            this.barraNormalTarget.classList.remove("hidden");
            this.barraSeleccionTarget.classList.add("hidden");
            this.barraSeleccionTarget.classList.remove("flex");
        }
    }

    limpiar() {
        this.sel.forEach((id) => {
            const li = this.itemTargets.find((i) => parseInt(i.dataset.fotoId, 10) === id);
            if (li) {
                li.classList.remove("ring-2", "ring-fm-accent");
                const c = li.querySelector("[data-fotos-melon--admin--galeria-target='check']");
                c.classList.add("hidden"); c.classList.remove("flex", "bg-fm-accent");
            }
        });
        this.sel.clear();
        this.refrescarBarra();
    }

    abrirLightbox(id) {
        this.actualId = id;
        this.lightboxImgTarget.src = this.cfg.verUrlBase + id + "/ver";
        this.lightboxDescargarTarget.href = this.cfg.verUrlBase + id + "/descargar";
        this.lightboxTarget.classList.remove("hidden");
        this.lightboxTarget.classList.add("flex");
    }

    cerrarLightbox(event) {
        if (event && event.target !== event.currentTarget && !event.target.closest("button")) return;
        this.lightboxTarget.classList.add("hidden");
        this.lightboxTarget.classList.remove("flex");
        this.actualId = null;
    }

    eliminarActual() {
        if (!this.actualId) return;
        if (!confirm("¿Eliminar esta foto? No se puede deshacer.")) return;
        const f = this.formEliminarTarget;
        f.action = this.cfg.verUrlBase + this.actualId;
        f.requestSubmit();
    }

    renombrarActual() {
        if (!this.actualId) return;
        const nuevo = prompt("Nuevo nombre:");
        if (!nuevo) return;
        const f = this.formRenombrarTarget;
        f.action = this.cfg.verUrlBase + this.actualId;
        this.formRenombrarInputTarget.value = nuevo;
        f.requestSubmit();
    }

    descargarSeleccionadas() {
        if (this.sel.size === 0) return;
        this.formZipIdsTarget.innerHTML = "";
        this.sel.forEach((id) => {
            const inp = document.createElement("input");
            inp.type = "hidden"; inp.name = "ids[]"; inp.value = id;
            this.formZipIdsTarget.appendChild(inp);
        });
        this.formZipTarget.requestSubmit();
    }

    abrirEliminar() {
        if (this.sel.size === 0) return;
        if (!confirm(`¿Eliminar ${this.sel.size} foto(s)? No se puede deshacer.`)) return;
        if (!confirm("¿Estás seguro? Esto es definitivo.")) return;
        this._eliminarSecuencial(Array.from(this.sel));
    }

    async _eliminarSecuencial(ids) {
        for (const id of ids) {
            await fetch(this.cfg.verUrlBase + id, {
                method: "DELETE",
                headers: { "X-CSRF-Token": this.cfg.csrf, "Accept": "text/html" },
                credentials: "same-origin"
            });
        }
        window.location.reload();
    }

    abrirMover() {
        if (this.sel.size === 0) return;
        const lista = this.moverListaTarget;
        lista.innerHTML = "";
        this.cfg.patentes.forEach((p) => {
            const btn = document.createElement("button");
            btn.type = "button";
            btn.className = "w-full text-left px-4 py-3 rounded-lg border " +
                (p.esActual ? "border-fm-accent bg-fm-accent-soft" : "border-fm-border hover:bg-fm-bg-subtle");
            btn.innerHTML = `<span class="font-semibold">${p.nombre}</span>` + (p.esActual ? ` <span class="text-xs text-fm-accent-deep">(actual)</span>` : "");
            btn.addEventListener("click", () => this._elegirPatente(p.id));
            lista.appendChild(btn);
        });
        document.querySelector("[data-modal-id='mover-fotos']").classList.remove("hidden");
        document.querySelector("[data-modal-id='mover-fotos']").classList.add("flex");
    }

    async _elegirPatente(patenteId) {
        const lista = this.moverListaTarget;
        lista.innerHTML = "<p class='text-fm-text-muted text-sm'>Cargando fechas...</p>";
        const res = await fetch(`/ventas/fotos_melon/admin/patentes/${patenteId}/fechas.json`, {
            headers: { "Accept": "application/json" }, credentials: "same-origin"
        });
        // Si no hay endpoint JSON de fechas, hacemos fallback: recargar mover con HTML.
        let fechas = [];
        try { fechas = await res.json(); } catch (e) { fechas = []; }
        lista.innerHTML = "";
        if (!Array.isArray(fechas) || fechas.length === 0) {
            lista.innerHTML = "<p class='text-fm-text-muted text-sm'>Esta patente no tiene carpetas.</p>";
            return;
        }
        fechas.forEach((fc) => {
            const esActual = fc.id === this.cfg.fechaActualId;
            const btn = document.createElement("button");
            btn.type = "button";
            btn.disabled = esActual;
            btn.className = "w-full text-left px-4 py-3 rounded-lg border " +
                (esActual ? "border-fm-accent bg-fm-accent-soft opacity-60" : "border-fm-border hover:bg-fm-bg-subtle");
            btn.innerHTML = `<span class="font-semibold">${fc.nombre_mostrado}</span>` + (esActual ? ` <span class="text-xs">(actual)</span>` : "");
            if (!esActual) btn.addEventListener("click", () => this._moverA(fc.id));
            lista.appendChild(btn);
        });
    }

    async _moverA(destinoId) {
        const ids = Array.from(this.sel);
        for (const id of ids) {
            const fd = new FormData();
            fd.append("fecha_carpeta_id", destinoId);
            await fetch(this.cfg.verUrlBase + id + "/mover", {
                method: "POST",
                headers: { "X-CSRF-Token": this.cfg.csrf, "Accept": "text/html" },
                credentials: "same-origin",
                body: fd
            });
        }
        window.location.reload();
    }
}