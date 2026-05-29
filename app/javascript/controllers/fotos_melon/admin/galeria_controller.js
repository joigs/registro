import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
    static targets = [
        "item", "barraNormal", "barraSeleccion", "contador", "datos",
        "lightbox", "lightboxImg", "lightboxDescargar", "lightboxBotones",
        "moverLista",
        "formEliminar", "formRenombrar", "formRenombrarInput",
        "formZip", "formZipIds"
    ];

    connect() {
        this.sel = new Set();
        this.cfg = JSON.parse(this.datosTarget.textContent);
        this.actualId = null;
        this._zoom = 1;
        this._panX = 0;
        this._panY = 0;
        this._dragging = false;
        this._dragStartX = 0;
        this._dragStartY = 0;
        this._panStartX = 0;
        this._panStartY = 0;
        // bound handlers
        this._handlerTeclado = this.manejarTeclado.bind(this);
        this._handlerWheel = this._manejarWheel.bind(this);
        this._handlerMouseDown = this._onMouseDown.bind(this);
        this._handlerMouseMove = this._onMouseMove.bind(this);
        this._handlerMouseUp = this._onMouseUp.bind(this);
        this._iniciarPolling();
    }

    disconnect() {
        if (this._pollTimer) clearInterval(this._pollTimer);
        window.removeEventListener("keydown", this._handlerTeclado);
        window.removeEventListener("wheel", this._handlerWheel);
        window.removeEventListener("mousemove", this._handlerMouseMove);
        window.removeEventListener("mouseup", this._handlerMouseUp);
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
        this._resetZoomPan();
        this.lightboxImgTarget.src = this.cfg.verUrlBase + id + "/ver";
        this.lightboxDescargarTarget.href = this.cfg.verUrlBase + id + "/descargar";
        this.lightboxTarget.classList.remove("hidden");
        this.lightboxTarget.classList.add("flex");
        document.body.style.overflow = "hidden";
        window.addEventListener("keydown", this._handlerTeclado);
        window.addEventListener("wheel", this._handlerWheel, { passive: false });
        this.lightboxImgTarget.addEventListener("mousedown", this._handlerMouseDown);
    }

    cerrarLightbox(event) {
        if (event && event.target !== event.currentTarget && !event.target.closest("button")) return;
        this.lightboxTarget.classList.add("hidden");
        this.lightboxTarget.classList.remove("flex");
        document.body.style.overflow = "";
        window.removeEventListener("keydown", this._handlerTeclado);
        window.removeEventListener("wheel", this._handlerWheel);
        window.removeEventListener("mousemove", this._handlerMouseMove);
        window.removeEventListener("mouseup", this._handlerMouseUp);
        this.lightboxImgTarget.removeEventListener("mousedown", this._handlerMouseDown);
        this._resetZoomPan();
        this.actualId = null;
    }

    _resetZoomPan() {
        this._zoom = 1;
        this._panX = 0;
        this._panY = 0;
        this._dragging = false;
        this._applyTransform();
        this.lightboxImgTarget.style.cursor = "default";
        this._setBotonesVisible(true);
    }

    _applyTransform() {
        this.lightboxImgTarget.style.transform =
            `translate(${this._panX}px, ${this._panY}px) scale(${this._zoom})`;
    }

    _clampPan() {
        const img = this.lightboxImgTarget;
        // Natural (unscaled) size of the image
        const naturalW = img.offsetWidth;
        const naturalH = img.offsetHeight;
        const extraX = (naturalW * (this._zoom - 1)) / 2;
        const extraY = (naturalH * (this._zoom - 1)) / 2;
        const MARGIN = 60;
        const maxX = extraX + MARGIN;
        const maxY = extraY + MARGIN;
        this._panX = Math.max(-maxX, Math.min(maxX, this._panX));
        this._panY = Math.max(-maxY, Math.min(maxY, this._panY));
    }

    _setBotonesVisible(visible) {
        if (!this.hasLightboxBotonesTarget) return;
        this.lightboxBotonesTarget.style.opacity = visible ? "1" : "0";
        this.lightboxBotonesTarget.style.pointerEvents = visible ? "auto" : "none";
        this.lightboxBotonesTarget.style.transition = "opacity 0.2s ease";
    }


    _manejarWheel(event) {
        if (!this.actualId) return;
        event.preventDefault();

        const STEP = 0.15;
        const MIN = 1;
        const MAX = 5;

        const img = this.lightboxImgTarget;
        const rect = img.getBoundingClientRect();

        const mouseX = event.clientX - (rect.left + rect.width / 2);
        const mouseY = event.clientY - (rect.top + rect.height / 2);

        const prevZoom = this._zoom;
        if (event.deltaY < 0) {
            this._zoom = Math.min(MAX, this._zoom + STEP);
        } else {
            this._zoom = Math.max(MIN, this._zoom - STEP);
        }

        if (prevZoom !== this._zoom) {
            const zoomRatio = this._zoom / prevZoom;
            this._panX = mouseX + (this._panX - mouseX) * zoomRatio;
            this._panY = mouseY + (this._panY - mouseY) * zoomRatio;
        }

        if (this._zoom === MIN) {
            this._panX = 0;
            this._panY = 0;
        }

        this._clampPan();
        this._applyTransform();

        const zoomed = this._zoom > 1;
        img.style.cursor = zoomed ? "grab" : "default";
        this._setBotonesVisible(!zoomed);
    }


    _onMouseDown(event) {
        if (this._zoom <= 1) return;
        event.preventDefault();
        this._dragging = true;
        this._dragStartX = event.clientX;
        this._dragStartY = event.clientY;
        this._panStartX = this._panX;
        this._panStartY = this._panY;
        this.lightboxImgTarget.style.cursor = "grabbing";
        window.addEventListener("mousemove", this._handlerMouseMove);
        window.addEventListener("mouseup", this._handlerMouseUp);
    }

    _onMouseMove(event) {
        if (!this._dragging) return;
        this._panX = this._panStartX + (event.clientX - this._dragStartX);
        this._panY = this._panStartY + (event.clientY - this._dragStartY);
        this._clampPan();
        this._applyTransform();
    }

    _onMouseUp() {
        if (!this._dragging) return;
        this._dragging = false;
        this.lightboxImgTarget.style.cursor = this._zoom > 1 ? "grab" : "default";
        window.removeEventListener("mousemove", this._handlerMouseMove);
        window.removeEventListener("mouseup", this._handlerMouseUp);
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