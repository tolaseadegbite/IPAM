import { Controller } from "@hotwired/stimulus"

// Escape flips the Plan/Build mode by clicking whichever option is
// currently inactive. Skipped while a modal dialog or popover owns the
// keyboard, so Esc keeps its dismiss meaning there.
export default class extends Controller {
  escape(event) {
    if (event.key !== "Escape" && event.key !== "Esc") return
    if (event.defaultPrevented) return
    if (document.querySelector("dialog[open]")) return
    if (document.querySelector(".popover:popover-open")) return

    const inactive = this.element.querySelector('button[aria-pressed="false"]')
    if (inactive) {
      event.preventDefault()
      inactive.click()
    }
  }
}
