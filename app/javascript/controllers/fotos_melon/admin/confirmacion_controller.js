import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
    static targets = ["paso", "inputWrap", "input", "error", "form", "hidden", "boton"];
    static values = { texto: String };

    connect() { this.nivel = 1; }

    avanzar() {
        if (this.nivel === 1) {
            this.nivel = 2;
            this.pasoTarget.textContent = "Una vez eliminado no se recupera. (paso 2 de 3)";
        } else if (this.nivel === 2) {
            this.nivel = 3;
            this.pasoTarget.textContent = "Confirma escribiendo el nombre abajo. (paso 3 de 3)";
            this.inputWrapTarget.classList.remove("hidden");
            this.botonTarget.textContent = "Eliminar";
            this.inputTarget.focus();
        } else {
            const val = this.inputTarget.value.trim().toUpperCase();
            const esperado = this.textoValue.trim().toUpperCase();
            if (val !== esperado) {
                this.errorTarget.classList.remove("hidden");
                return;
            }
            this.hiddenTarget.value = this.inputTarget.value.trim();
            this.formTarget.requestSubmit();
        }
    }
}