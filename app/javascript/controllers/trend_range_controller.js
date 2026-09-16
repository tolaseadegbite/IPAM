import { Controller } from "@hotwired/stimulus"

const ACTIVE_CLASSES = ["bg-white", "dark:bg-zinc-600", "text-zinc-900", "dark:text-white", "shadow-sm"]
const STORAGE_KEY = "trend-range"

// Pill switcher for the dashboard events chart (1H / 24H / 7D / 14D).
// Every range ships in the datasets value, so switching is instant with
// no server round-trip — and scan broadcasts refresh all ranges at once,
// so the selection survives live updates. Persisted in localStorage and
// re-applied on reconnect (broadcasts replace this node).
export default class extends Controller {
  static targets = ["button"]
  static values = { datasets: Object, current: String }

  connect() {
    requestAnimationFrame(() => this.select(this.#stored || this.currentValue))
  }

  select(event) {
    const range = typeof event === "string" ? event : event.params.range
    if (!this.datasetsValue[range]) return

    this.currentValue = range
    try {
      localStorage.setItem(STORAGE_KEY, range)
    } catch (_error) {
      // Private browsing etc: selection simply won't persist.
    }
    this.#paintButtons(range)

    const chart = this.application.getControllerForElementAndIdentifier(this.#canvas, "chart")
    if (chart) chart.updateData(this.datasetsValue[range])
  }

  #paintButtons(range) {
    this.buttonTargets.forEach((button) => {
      const active = button.dataset.range === range
      button.setAttribute("aria-pressed", active.toString())
      if (active) {
        button.classList.add(...ACTIVE_CLASSES)
      } else {
        button.classList.remove(...ACTIVE_CLASSES)
      }
    })
  }

  get #canvas() {
    return this.element.querySelector("canvas")
  }

  get #stored() {
    try {
      return localStorage.getItem(STORAGE_KEY)
    } catch (_error) {
      return null
    }
  }
}
