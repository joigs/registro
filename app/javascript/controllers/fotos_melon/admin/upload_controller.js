import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
    static targets = ["form", "input", "overlay"];

    abrir() { this.inputTarget.click(); }

    enviar() {
        if (this.inputTarget.files.length === 0) return;
        this.overlayTarget.classList.remove("hidden");
        this.overlayTarget.classList.add("flex");
        this.formTarget.requestSubmit();
    }
}