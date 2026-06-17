import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { threshold: { type: Number, default: 100 } }
  #wasNearBottom = true

  connect() {
    this.element.scrollTop = this.element.scrollHeight
    this.element.addEventListener("scroll", () => {
      this.#wasNearBottom = this.element.scrollHeight - this.element.scrollTop - this.element.clientHeight < this.thresholdValue
    })
    this.observer = new MutationObserver(() => {
      if (this.#wasNearBottom) this.#scrollToBottom()
    })
    this.observer.observe(this.element, { childList: true, subtree: true, characterData: true })
  }

  disconnect() {
    this.observer?.disconnect()
  }

  #scrollToBottom() {
    requestAnimationFrame(() => {
      this.element.scrollTo({ top: this.element.scrollHeight, behavior: "smooth" })
    })
  }
}
