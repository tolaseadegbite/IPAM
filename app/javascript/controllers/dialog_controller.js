import { Controller } from "@hotwired/stimulus"
import { snapshotDialog, confirmDiscardIfDirty } from "controllers/dirty_confirm"

export default class extends Controller {
  static targets = [ "content" ]

  #snapshot = null
  #onCancel = null

  connect() {
    // Listen for a "dialog:close" event on the window.
    // When it happens, call this controller's "close" method.
    window.addEventListener("dialog:close", this.close.bind(this))
  }

  showModal() {
    this.contentTarget.showModal()
    this.#snapshot = snapshotDialog(this.contentTarget)
    this.#onCancel = (event) => {
      event.preventDefault()
      this.requestClose()
    }
    this.contentTarget.addEventListener("cancel", this.#onCancel)
  }

  disconnect() {
    this.contentTarget.removeEventListener("cancel", this.#onCancel)
  }

  requestClose() {
    confirmDiscardIfDirty(this.contentTarget, this.#snapshot || new Map(), () => this.close())
  }

  close() {
    // Check if the dialog is actually open before trying to close it
    if (this.contentTarget.hasAttribute("open")) {
      this.contentTarget.close()
    }
  }

  closeOnClickOutside({ target }) {
    if (target.nodeName === "DIALOG") {
      this.requestClose()
    }
  }
}
