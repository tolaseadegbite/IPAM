import { Controller } from "@hotwired/stimulus"

const ACTIVE_CLASSES = ["bg-zinc-900", "text-white", "dark:bg-zinc-100", "dark:text-zinc-900"]
const INACTIVE_CLASSES = ["text-zinc-500", "hover:text-zinc-900", "dark:text-zinc-400", "dark:hover:text-zinc-100"]

// The pool buttons live outside the ip_pool Turbo Frame on purpose (so
// typing in the address box never loses focus on resubmit), which means
// frame navigations never re-render their highlight. Repaint from the
// frame's own URL on connect and after every successful load instead —
// the highlight can never disagree with the grid, not even on failures.
export default class extends Controller {
  static targets = ["button"]

  initialize() {
    this.repaint = this.repaint.bind(this)
  }

  connect() {
    document.addEventListener("turbo:frame-load", this.repaint)
    this.repaint()
  }

  disconnect() {
    document.removeEventListener("turbo:frame-load", this.repaint)
  }

  repaint(event) {
    if (event && event.target.id !== "ip_pool") return

    const pool = this.#currentPool()
    this.buttonTargets.forEach((button) => {
      const active = (button.dataset.pool || "") === pool
      button.setAttribute("aria-pressed", active.toString())
      button.classList.remove(...ACTIVE_CLASSES, ...INACTIVE_CLASSES)
      button.classList.add(...(active ? ACTIVE_CLASSES : INACTIVE_CLASSES))
    })
  }

  #currentPool() {
    const frame = document.getElementById("ip_pool")
    if (!frame || !frame.src) return ""

    return new URL(frame.src, window.location.origin).searchParams.get("pool") || ""
  }
}
