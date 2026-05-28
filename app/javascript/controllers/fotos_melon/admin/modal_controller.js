import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
    static targets = ["modal"];

    open(event) {
        const id = event.currentTarget.dataset.modalId;
        this.modalTargets.forEach((m) => {
            if (m.dataset.modalId === id) {
                m.classList.remove("hidden");
                m.classList.add("flex");
            }
        });
    }

    close() {
        this.modalTargets.forEach((m) => {
            m.classList.add("hidden");
            m.classList.remove("flex");
        });
    }

    backdrop(event) {
        if (event.target === event.currentTarget) this.close();
    }
}