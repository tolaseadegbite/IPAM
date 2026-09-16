import { Controller } from "@hotwired/stimulus"
// import { Chart, registerables } from "https://esm.sh/chart.js@4.5.0?standalone"

import { Chart, registerables } from "chart.js"

export default class extends Controller {
  static values = { type: { type: String, default: "line" }, data: Object, options: Object }

  initialize() {
    Chart.register(...registerables)
    this.handleThemeChange = this.handleThemeChange.bind(this)
    this.#applyDefaults()
  }

  connect() {
    window.addEventListener("app:theme-change", this.handleThemeChange)
    this.#build()
  }

  disconnect() {
    window.removeEventListener("app:theme-change", this.handleThemeChange)
    this.#destroy()
  }

  // Theme switches swap CSS variables but canvas keeps old pixels.
  // Rebuild so palette keys re-resolve against the new theme.
  handleThemeChange() {
    this.#destroy()
    this.#applyDefaults()
    this.#build()
  }

  #build() {
    this.chart = new Chart(this.element, this.#settings)
  }

  #destroy() {
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  }

  #applyDefaults() {
    Chart.defaults.backgroundColor = getComputedStyle(document.body).backgroundColor
    Chart.defaults.borderColor = getComputedStyle(document.body).borderColor
    Chart.defaults.color = getComputedStyle(document.body).color
    Chart.defaults.font.family = getComputedStyle(document.body).fontFamily
    Chart.defaults.font.size = 12
  }

  // Swaps datasets in place (used by trend-range). Persists to dataValue
  // so theme-change rebuilds keep the selected range, not the default.
  updateData(data) {
    this.dataValue = data
    if (this.chart) {
      this.chart.data = this.#resolveThemeColors(data)
      this.chart.update()
    }
  }

  get #settings() {
    return { type: this.typeValue, data: this.#resolveThemeColors(this.dataValue), options: this.optionsValue }
  }

  // Chart.js draws on canvas, so CSS var() references never resolve there.
  // Ruby builders emit palette keys ("--chart-info"); resolve them against
  // the live theme before handing data to Chart.js.
  #resolveThemeColors(value) {
    if (typeof value === "string") return this.#resolveColor(value)
    if (Array.isArray(value)) return value.map((item) => this.#resolveThemeColors(item))
    if (value && typeof value === "object") {
      return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, this.#resolveThemeColors(item)]))
    }
    return value
  }

  #resolveColor(color) {
    if (!color.startsWith("--")) return color

    return getComputedStyle(document.documentElement).getPropertyValue(color).trim() || color
  }
}
