import { Controller } from "@hotwired/stimulus"

// Counts interface rows in the device form: caps Add-IP at the policy
// maximum, removes rows on demand. Server-side validation remains the
// real enforcement; this only keeps the UI honest.
export default class extends Controller {
  static targets = ["add", "hint"]
  static values = { max: Number }

  connect() {
    // Appended rows land inside #interfaces-container (a descendant), so
    // observe the subtree — direct childList alone never fires for them.
    this.observer = new MutationObserver(() => this.#refresh())
    this.observer.observe(this.element, { childList: true, subtree: true })
    this.#refresh()
  }

  disconnect() {
    this.observer?.disconnect()
  }

  remove(event) {
    event.currentTarget.closest("[data-interface-row]")?.remove()
  }

  #refresh() {
    const count = this.element.querySelectorAll("[data-interface-row]").length
    const maxed = count >= this.maxValue
    if (this.hasAddTarget) {
      this.addTarget.classList.toggle("hidden", maxed)
      this.addTarget.setAttribute("aria-disabled", maxed)
    }
    // Compare before assigning: unguarded textContent writes re-trigger
    // this subtree observer forever, pegging the tab and starving the
    // driver. classList.toggle above is already a no-op when unchanged.
    if (this.hasHintTarget) {
      const text = `Up to ${this.maxValue} interfaces: one per segment (.13/.30 and .15/.16 excluded).`
      if (this.hintTarget.textContent !== text) this.hintTarget.textContent = text
    }
  }
}
