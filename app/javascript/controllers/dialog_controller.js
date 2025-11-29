import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "content" ]

  connect() {
    // Listen for a "dialog:close" event on the window.
    // When it happens, call this controller's "close" method.
    window.addEventListener("dialog:close", this.close.bind(this))
  }

  showModal() {
    this.contentTarget.showModal()
  }

  close() {
    // Check if the dialog is actually open before trying to close it
    if (this.contentTarget.hasAttribute("open")) {
      this.contentTarget.close()
    }
  }

  closeOnClickOutside({ target }) {
    if (target.nodeName === "DIALOG") {
      this.close()
    }
  }
}