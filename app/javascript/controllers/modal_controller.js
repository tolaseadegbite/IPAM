import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.showModal()
  }

  // hide modal on successful form submission
  submitEnd(e) {
    if (e.detail.success) {
      this.close()
    }
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
      this.close()
    }
  }
}