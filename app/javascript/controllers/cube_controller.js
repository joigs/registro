import { Controller } from "@hotwired/stimulus"

/*
 *  Convierte una lista UL/LI anidada en un OLAP “pirámide horizontal”.
 *  –  Cada li “nodo” tiene data-action="click->cube#toggle"
 *  –  El ul interno (sub-nivel) inicia con class="hidden".
 */
export default class extends Controller {
    toggle (event) {
        // Evita que un click en un hijo vuelva a cerrar el abuelo
        event.stopPropagation()

        const li    = event.currentTarget
        const child = li.querySelector(":scope > ul")
        if (!child) return  // no hay sub-nivel

        child.classList.toggle("hidden")
        li.classList.toggle("open")
    }
}
