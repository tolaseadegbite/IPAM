import { Controller } from "@hotwired/stimulus"

// Counts interface rows in the device form: caps Add-IP at the policy
// maximum, removes rows on demand. Server-side validation remains the
// real enforcement; this only keeps the UI honest.
export default class extends Controller {
  static targets = ["add", "hint", "flag"]
  static values = { max: Number, total: Number }

  connect() {
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

  // The infrastructure flag widens the cap live: re-evaluate on toggle.
  retoggle() {
    this.#refresh()
  }

  #maxRows() {
    if (this.hasFlagTarget && this.flagTarget.checked) {
      return this.totalValue
    }
    return this.maxValue
  }

  #refresh() {
    // Disconnect while applying our own writes: observer callbacks from
    // our own mutations are pure feedback, and any write that isn't a
    // DOM no-op would otherwise ping-pong forever and wedge the tab.
    this.observer.disconnect()
    try {
      const max = this.#maxRows()
      const count = this.element.querySelectorAll("[data-interface-row]").length
      const maxed = count >= max
      if (this.hasAddTarget) {
        this.addTarget.classList.toggle("hidden", maxed)
        this.#setAttribute(this.addTarget, "aria-disabled", String(maxed))
      }
      if (this.hasHintTarget) {
        const text = this.hasFlagTarget && this.flagTarget.checked ?
          `Up to ${max} interfaces (infrastructure: all segments allowed).` :
          `Up to ${max} interfaces: one per segment (.13/.30 and .15/.16 excluded).`
        if (this.hintTarget.textContent !== text) this.hintTarget.textContent = text
      }
    } finally {
      this.observer.observe(this.element, { childList: true, subtree: true })
    }
  }

  // setAttribute is only guaranteed mutation-free when the value is
  // identical — compare first so our own writes can never re-trigger us.
  #setAttribute(element, name, value) {
    if (element.getAttribute(name) !== value) element.setAttribute(name, value)
  }
}
