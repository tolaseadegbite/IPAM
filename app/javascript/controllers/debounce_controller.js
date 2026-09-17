import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { delay: { type: Number, default: 300 } }

  submit() {
    clearTimeout(this.timeout)

    this.timeout = setTimeout(() => {
      // The form may be gone by now (Turbo navigated mid-typing):
      // submitting a detached form only logs console noise.
      if (!this.element.isConnected) return

      this.element.requestSubmit()
    }, this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}