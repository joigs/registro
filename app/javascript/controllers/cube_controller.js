// app/javascript/controllers/cube_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    toggle (event) {
        event.stopPropagation()

        const arrow = event.currentTarget
        const li    = arrow.closest("li")
        const child = li.querySelector(":scope > ul")
        if (!child) return

        const open = !child.classList.toggle("hidden")
        arrow.textContent = open ? "▼" : "►"
    }
}
