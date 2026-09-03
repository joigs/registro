import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"

export default class extends Controller {
    static targets = ["year", "month", "from", "to"]

    connect() {
        this.beforeCacheHandler = this.beforeCache.bind(this)
        document.addEventListener("turbo:before-cache", this.beforeCacheHandler)

        this.initializePickers()
    }

    disconnect() {
        document.removeEventListener("turbo:before-cache", this.beforeCacheHandler)
        this.destroyPickers()
    }

    beforeCache() {
        this.destroyPickers()
    }

    initializePickers() {
        if (!this.hasFromTarget || !this.hasToTarget) return

        this.destroyPickers()

        const bounds = this.monthBounds()

        if (!bounds) return

        this.fromPicker = flatpickr(this.fromTarget, {
            dateFormat: "Y-m-d",

            // Lo que ve el usuario
            altInput: true,
            altFormat: "d/m/Y",

            allowInput: false,

            minDate: bounds.min,
            maxDate: bounds.max,

            onChange: () => {
                this.syncLimits()
            }
        })

        this.toPicker = flatpickr(this.toTarget, {
            dateFormat: "Y-m-d",

            // Lo que ve el usuario
            altInput: true,
            altFormat: "d/m/Y",

            allowInput: false,

            minDate: bounds.min,
            maxDate: bounds.max,

            onChange: () => {
                this.syncLimits()
            }
        })

        this.syncLimits()
    }

    selectionChanged() {
        if (!this.hasFromTarget || !this.hasToTarget) return

        const bounds = this.monthBounds()

        // "Año completo"
        if (!bounds) {
            this.fromTarget.disabled = true
            this.toTarget.disabled = true

            if (this.fromPicker?.altInput) {
                this.fromPicker.altInput.disabled = true
            }

            if (this.toPicker?.altInput) {
                this.toPicker.altInput.disabled = true
            }

            return
        }

        this.fromTarget.disabled = false
        this.toTarget.disabled = false

        if (this.fromPicker?.altInput) {
            this.fromPicker.altInput.disabled = false
        }

        if (this.toPicker?.altInput) {
            this.toPicker.altInput.disabled = false
        }

        const defaultFrom = bounds.min
        const defaultTo = this.defaultEndDate(
            Number(this.yearTarget.value),
            Number(this.monthTarget.value)
        )

        this.fromPicker.set("minDate", bounds.min)
        this.fromPicker.set("maxDate", bounds.max)

        this.toPicker.set("minDate", bounds.min)
        this.toPicker.set("maxDate", bounds.max)

        this.fromPicker.setDate(defaultFrom, false, "Y-m-d")
        this.toPicker.setDate(defaultTo, false, "Y-m-d")

        this.syncLimits()
    }

    syncLimits() {
        if (!this.fromPicker || !this.toPicker) return

        const bounds = this.monthBounds()
        if (!bounds) return

        const from = this.fromPicker.selectedDates[0]
        const to = this.toPicker.selectedDates[0]

        this.fromPicker.set(
            "maxDate",
            to || bounds.max
        )

        this.toPicker.set(
            "minDate",
            from || bounds.min
        )
    }

    monthBounds() {
        if (!this.hasYearTarget || !this.hasMonthTarget) return null

        const year = Number(this.yearTarget.value)
        const monthValue = this.monthTarget.value

        if (monthValue === "all") return null

        const month = Number(monthValue)

        if (!year || !month) return null

        const lastDay = new Date(year, month, 0).getDate()

        return {
            min: this.isoDate(year, month, 1),
            max: this.isoDate(year, month, lastDay)
        }
    }

    defaultEndDate(year, month) {
        const today = new Date()

        const currentYear = today.getFullYear()
        const currentMonth = today.getMonth() + 1

        if (year === currentYear && month === currentMonth) {
            return this.isoDate(
                year,
                month,
                today.getDate()
            )
        }

        const lastDay = new Date(year, month, 0).getDate()

        return this.isoDate(year, month, lastDay)
    }

    isoDate(year, month, day) {
        return [
            String(year).padStart(4, "0"),
            String(month).padStart(2, "0"),
            String(day).padStart(2, "0")
        ].join("-")
    }

    destroyPickers() {
        if (this.fromPicker) {
            this.fromPicker.destroy()
            this.fromPicker = null
        }

        if (this.toPicker) {
            this.toPicker.destroy()
            this.toPicker = null
        }
    }
}