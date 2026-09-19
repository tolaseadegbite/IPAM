import { Controller } from "@hotwired/stimulus"

// Upward infinite scroll for chat history. A sentinel at the top of the
// message list carries the oldest loaded id; scrolling it into view
// fetches the next older window and prepends it, compensating scrollTop
// so the view stays anchored instead of jumping.
export default class extends Controller {
  static targets = ["sentinel"]
  static values = { loading: { type: Boolean, default: false } }

  connect() {
    this.observer = new IntersectionObserver((entries) => {
      if (entries[0].isIntersecting) this.#loadOlder()
    }, { root: this.element, rootMargin: "200px" })
    if (this.hasSentinelTarget) this.observer.observe(this.sentinelTarget)
  }

  disconnect() {
    this.observer?.disconnect()
  }

  async #loadOlder() {
    if (this.loadingValue || !this.hasSentinelTarget) return
    this.loadingValue = true
    this.observer.unobserve(this.sentinelTarget)

    const oldestId = this.sentinelTarget.dataset.oldestId
    const previousHeight = this.element.scrollHeight
    try {
      const response = await fetch(`${window.location.pathname}?before_id=${oldestId}`, {
        headers: { Accept: "text/vnd.turbo-stream.html" }
      })
      if (response.ok) {
        Turbo.renderStreamMessage(await response.text())
        this.element.scrollTop += this.element.scrollHeight - previousHeight
        if (this.hasSentinelTarget) this.observer.observe(this.sentinelTarget)
      }
    } catch (error) {
      console.error("History load failed:", error)
    } finally {
      this.loadingValue = false
    }
  }
}
