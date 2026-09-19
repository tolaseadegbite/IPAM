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
    // Flag the container so the autoscroll controller never mistakes a
    // history prepend for content worth snapping to the bottom for.
    this.element.dataset.historyLoading = "true"
    try {
      const response = await fetch(`${window.location.pathname}?before_id=${oldestId}`, {
        headers: { Accept: "text/vnd.turbo-stream.html" }
      })
      if (response.ok) {
        Turbo.renderStreamMessage(await response.text())
        // Turbo lands the DOM asynchronously: compensate only after layout,
        // otherwise the delta measures zero and the view jumps to the top.
        await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)))
        this.element.scrollTop += this.element.scrollHeight - previousHeight
        if (this.hasSentinelTarget) this.observer.observe(this.sentinelTarget)
      } else {
        this.#markFailed(response.status)
      }
    } catch (error) {
      this.#markFailed(error)
    } finally {
      delete this.element.dataset.historyLoading
      this.loadingValue = false
    }
  }

  // A stuck silent spinner is worse than an error: leave the sentinel in
  // place with a retry affordance. Re-arm on the next scroll (not
  // immediately — the sentinel is already intersecting, which would
  // retry in a tight loop on persistent failures).
  #markFailed(reason) {
    console.error("History load failed:", reason)
    if (this.hasSentinelTarget) {
      this.sentinelTarget.innerHTML =
        '<span>Couldn\'t load older messages — scroll to retry</span>'
      this.element.addEventListener("scroll", () => {
        if (this.hasSentinelTarget) this.observer.observe(this.sentinelTarget)
      }, { once: true })
    }
  }
}
