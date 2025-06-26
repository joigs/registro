// app/javascript/controllers/theme_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["icon"]

    connect() {
        this.applySavedTheme()
    }

    toggle() {
        const html = document.documentElement
        const dark = html.classList.toggle("dark")  // añade o quita
        localStorage.theme = dark ? "dark" : "light"
        this.updateIcon(dark)
    }

    applySavedTheme() {
        const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches
        const saved = localStorage.theme          // "dark" | "light" | undefined
        const dark = saved ? saved === "dark" : prefersDark
        if (dark) document.documentElement.classList.add("dark")
        this.updateIcon(dark)
    }

    updateIcon(dark) {
        this.iconTarget.textContent = dark ? "☀️" : "🌙"
    }
}
