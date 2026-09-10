import { Controller } from "@hotwired/stimulus"
import { snapshotDialog, confirmDiscardIfDirty } from "controllers/dirty_confirm"

export default class extends Controller {
  #snapshot = null
  #onCancel = null

  connect() {
    this.element.showModal()
    this.#snapshot = snapshotDialog(this.element)
    this.#onCancel = (event) => {
      event.preventDefault()
      this.requestClose()
    }
    this.element.addEventListener("cancel", this.#onCancel)
  }

  disconnect() {
    this.element.removeEventListener("cancel", this.#onCancel)
  }

  // hide modal on successful form submission
  submitEnd(e) {
    if (e.detail.success) {
      this.#snapshot = snapshotDialog(this.element)
      this.close()
    }
  }

  requestClose() {
    confirmDiscardIfDirty(this.element, this.#snapshot, () => this.close())
  }

  close() {
    this.element.close()
    // Find the global modal frame and clear it
    const frame = document.getElementById("modal")
    frame.removeAttribute("src") // Important for subsequent visits
    frame.innerHTML = ""
  }

  clickOutside(event) {
    if (event.target === this.element) {
      this.requestClose()
    }
  }
}
