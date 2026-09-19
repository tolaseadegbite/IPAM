import { Controller } from "@hotwired/stimulus"

// Upward infinite scroll for chat history. A sentinel at the top of the
// message list carries the oldest loaded id; scrolling it into view
// fetches the next older window and prepends it, compensating scrollTop
// so the view stays anchored instead of jumping.
//
// Pacing, not position, bounds the trigger: fires are cooldown-limited
// (with exponential backoff on failures), so momentum scrolling and
// post-insertion reflow can never machine-gun the history — yet slow,
// continuous scrolling always makes progress without any exit/re-enter
// dance.
const COOLDOWN_MS = 1500
const MAX_BACKOFF_MS = 30000

export default class extends Controller {
  static targets = ["sentinel"]
  static values = { loading: { type: Boolean, default: false } }

  connect() {
    this.lastFiredAt = 0
    this.consecutiveFailures = 0
    this.observer = new IntersectionObserver((entries) => {
      if (entries[0].isIntersecting) this.#loadOlder()
    }, { root: this.element, rootMargin: "200px" })
    if (this.hasSentinelTarget) this.observer.observe(this.sentinelTarget)
  }

  disconnect() {
    this.observer?.disconnect()
  }

  #cooldownMs() {
    return Math.min(COOLDOWN_MS * (2 ** this.consecutiveFailures), MAX_BACKOFF_MS)
  }

  async #loadOlder() {
    if (this.loadingValue || !this.hasSentinelTarget) return
    if (Date.now() - this.lastFiredAt < this.#cooldownMs()) return
    this.loadingValue = true
    this.lastFiredAt = Date.now()
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
        if (this.hasSentinelTarget) {
          if (this.sentinelTarget.dataset.oldestId === oldestId) {
            // The load applied nothing new (same cursor still in the DOM):
            // surface it as a failure instead of looping silently.
            this.#markFailed("sentinel did not advance")
          } else {
            this.consecutiveFailures = 0
            this.observer.observe(this.sentinelTarget)
          }
        } else {
          this.consecutiveFailures = 0
        }
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
  // place with a retry affordance. Re-observing immediately is safe — the
  // cooldown paces retries instead of tight-looping them.
  #markFailed(reason) {
    console.error("History load failed:", reason)
    this.consecutiveFailures += 1
    if (this.hasSentinelTarget) {
      this.sentinelTarget.innerHTML =
        '<span>Couldn\'t load older messages — scroll to retry</span>'
      this.observer.observe(this.sentinelTarget)
    }
  }
}
