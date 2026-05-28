import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
    static targets = [
        "item", "barraNormal", "barraSeleccion", "contador", "datos",
        "lightbox", "lightboxImg", "lightboxDescargar",
        "moverLista",
        "formEliminar", "formRenombrar", "formRenombrarInput",
        "formZip", "formZipIds"
    ];

    connect() {
        this.sel = new Set();
        this.cfg = JSON.parse(this.datosTarget.textContent);
        this.actualId = null;
        this._handlerTeclado = this.manejarTeclado.bind(this);
        this._iniciarPolling();
    }

    disconnect() {
        if (this._pollTimer) clearInterval(this._pollTimer);
        window.removeEventListener("keydown", this._handlerTeclado);
    }

    _iniciarPolling() {
        this._pollTimer = setInterval(() => this._chequearCambios(), 15000);
    }

    async _chequearCambios() {
        try {
            const res = await fetch(this.cfg.fechasUrlBase + "x", { method: "HEAD" }).catch(() => null);
        } catch (e) { }
        try {
            const url = `/ventas/fotos_melon/admin/fechas/${this.cfg.fechaActualId}.json`;
        } catch (e) { }
    }

    refrescar() {
        window.location.reload();
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
            if (check) { check.classList.add("hidden"); check.classList.remove("flex", "bg-fm-accent"); }
        } else {
            this.sel.add(id);
            li.classList.add("ring-2", "ring-fm-accent");
            if (check) { check.classList.remove("hidden"); check.classList.add("flex", "bg-fm-accent"); }
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
        this.itemTargets.forEach((li) => {
            li.classList.remove("ring-2", "ring-fm-accent");
            const c = li.querySelector("[data-fotos-melon--admin--galeria-target='check']");
            if (c) { c.classList.add("hidden"); c.classList.remove("flex", "bg-fm-accent"); }
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
        window.addEventListener("keydown", this._handlerTeclado);
    }

    cerrarLightbox(event) {
        if (event && event.target !== event.currentTarget && !event.target.closest("button")) return;
        this.lightboxTarget.classList.add("hidden");
        this.lightboxTarget.classList.remove("flex");
        window.removeEventListener("keydown", this._handlerTeclado);
        this.actualId = null;
    }

    manejarTeclado(event) {
        if (!this.actualId) return;

        if (event.key === "Escape") {
            this.cerrarLightbox();
            return;
        }

        if (event.key === "ArrowRight" || event.key === "ArrowLeft") {
            const ids = this.itemTargets.map((li) => parseInt(li.dataset.fotoId, 10));
            const index = ids.indexOf(this.actualId);

            if (index === -1) return;

            let nuevoIndex;
            if (event.key === "ArrowRight") {
                nuevoIndex = (index + 1) % ids.length;
            } else {
                nuevoIndex = (index - 1 + ids.length) % ids.length;
            }

            this.abrirLightbox(ids[nuevoIndex]);
        }
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
            btn.innerHTML = `<span class="font-semibold">${p.nombre}</span>` +
                (p.esActual ? ` <span class="text-xs text-fm-accent-deep">(actual)</span>` : "");
            btn.addEventListener("click", () => this._elegirPatente(p.id));
            lista.appendChild(btn);
        });
        const modal = document.querySelector("[data-modal-id='mover-fotos']");
        modal.classList.remove("hidden");
        modal.classList.add("flex");
    }

    async _elegirPatente(patenteId) {
        const lista = this.moverListaTarget;
        lista.innerHTML = "<p class='text-fm-text-muted text-sm'>Cargando fechas...</p>";
        let fechas = [];
        try {
            const res = await fetch(`/ventas/fotos_melon/admin/patentes/${patenteId}/fechas.json`, {
                headers: { "Accept": "application/json" }, credentials: "same-origin"
            });
            fechas = await res.json();
        } catch (e) { fechas = []; }

        lista.innerHTML = "";
        const volver = document.createElement("button");
        volver.type = "button";
        volver.className = "text-fm-accent text-sm mb-2";
        volver.textContent = "← Volver a patentes";
        volver.addEventListener("click", () => this.abrirMover());
        lista.appendChild(volver);

        if (!Array.isArray(fechas) || fechas.length === 0) {
            const p = document.createElement("p");
            p.className = "text-fm-text-muted text-sm";
            p.textContent = "Esta patente no tiene carpetas de fecha.";
            lista.appendChild(p);
            return;
        }
        fechas.forEach((fc) => {
            const esActual = fc.id === this.cfg.fechaActualId;
            const btn = document.createElement("button");
            btn.type = "button";
            btn.disabled = esActual;
            btn.className = "w-full text-left px-4 py-3 rounded-lg border " +
                (esActual ? "border-fm-accent bg-fm-accent-soft opacity-60 cursor-not-allowed" : "border-fm-border hover:bg-fm-bg-subtle");
            btn.innerHTML = `<span class="font-semibold">${fc.nombre_mostrado}</span>` +
                (esActual ? ` <span class="text-xs">(actual)</span>` : "");
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