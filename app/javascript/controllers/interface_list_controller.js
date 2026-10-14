import { Controller } from "@hotwired/stimulus"

// Counts interface rows in the device form: caps Add-IP at the policy
// maximum, adds blank rows from the embedded template, removes rows on
// demand. Row insertion is fully client-side (no server roundtrip), so
// there is no request that can be misrouted. Server-side validation
// remains the real enforcement; this only keeps the UI honest.
export default class extends Controller {
  static targets = ["add", "hint", "flag", "template"]
  static values = { max: Number, total: Number }

  // Private instance state must be declared: using an undeclared #field
  // is a SyntaxError that kills the whole module (and every action in
  // this controller) while every other controller keeps working.
  #seq = 0

  connect() {
    this.#refresh()
  }

  // Clone the server-rendered blank row, stamp a unique suffix so frame
  // and filter ids stay independent per row, and append it.
  add() {
    this.#seq += 1
    const suffix = `${Date.now().toString(36)}${this.#seq}`
    const html = this.templateTarget.innerHTML.replaceAll("__ROW__", suffix)
    this.#container().insertAdjacentHTML("beforeend", html)
    this.#refresh()
  }

  remove(event) {
    event.currentTarget.closest("[data-interface-row]")?.remove()
    this.#refresh()
  }

  // The infrastructure flag widens the cap live: re-evaluate on toggle.
  retoggle() {
    this.#refresh()
  }

  #container() {
    return this.element.querySelector("#interfaces-container")
  }

  #maxRows() {
    if (this.hasFlagTarget && this.flagTarget.checked) {
      return this.totalValue
    }
    return this.maxValue
  }

  #refresh() {
    const container = this.#container()
    if (!container) return
    const max = this.#maxRows()
    const count = container.querySelectorAll("[data-interface-row]").length
    const maxed = count >= max
    if (this.hasAddTarget) {
      this.addTarget.classList.toggle("hidden", maxed)
      this.#setAttribute(this.addTarget, "aria-disabled", String(maxed))
    }
    // Compare before assigning: textContent writes are cheap but pointless
    // when identical; keep them idempotent by construction.
    if (this.hasHintTarget) {
      const text = this.hasFlagTarget && this.flagTarget.checked ?
        `Up to ${max} interfaces (infrastructure: all segments allowed).` :
        `Up to ${max} interfaces: one per segment (.13/.30 and .15/.16 excluded).`
      if (this.hintTarget.textContent !== text) this.hintTarget.textContent = text
    }
  }

  #setAttribute(element, name, value) {
    if (element.getAttribute(name) !== value) element.setAttribute(name, value)
  }
}
