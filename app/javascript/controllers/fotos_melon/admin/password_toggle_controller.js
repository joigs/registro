import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
    static targets = ["input", "iconShow", "iconHide"];

    toggle() {
        const visible = this.inputTarget.type === "text";
        this.inputTarget.type = visible ? "password" : "text";
        this.iconShowTarget.classList.toggle("hidden", !visible);
        this.iconHideTarget.classList.toggle("hidden", visible);
    }
}