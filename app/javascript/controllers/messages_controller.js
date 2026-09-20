import { Controller } from "@hotwired/stimulus"
import MessagePaginator from "models/message_paginator"
import ScrollManager from "models/scroll_manager"

// Chat message list: paginated history in both directions with scroll
// anchoring, plus a "Jump to newest" pill when live arrivals land while
// reading history. Ported from Campfire's messages controller, minus
// formatting/sounds/search (rows arrive server-rendered here).
export default class extends Controller {
  static targets = ["messages", "latest"]
  static values = { pageUrl: String }

  #paginator
  #scrollManager

  connect() {
    this.#paginator = new MessagePaginator(
      this.messagesTarget, this.pageUrlValue, this.#upToDateChanged.bind(this)
    )
    this.#scrollManager = new ScrollManager(this.messagesTarget)

    this.#scrollManager.autoscroll(true)
    this.#paginator.monitor()
  }

  disconnect() {
    this.#paginator.disconnect()
  }

  // Actions

  async beforeStreamRender(event) {
    const stream = event.detail.newStream
    if (!stream) return
    const target = stream.getAttribute("target")
    const targetElement = target && document.getElementById(target)
    if (!targetElement || !this.messagesTarget.contains(targetElement)) return

    const render = event.detail.render
    if (target === this.messagesTarget.id) {
      if (this.#alreadyRendered(stream)) {
        event.preventDefault()
        return
      }
      event.detail.render = async (streamElement) => {
        if (this.#paginator.upToDate) {
          const didScroll = await this.#scrollManager.autoscroll(false, async () => {
            await render(streamElement)
            await nextFrame()
          })
          if (!didScroll) this.latestTarget.hidden = false
        } else {
          this.latestTarget.hidden = false
        }
      }
    } else {
      event.detail.render = async (streamElement) => {
        await this.#scrollManager.keepScroll(false, () => render(streamElement))
      }
    }
  }

  async composerSubmitted(event) {
    if (event.target?.id !== "new_message") return
    if (!this.#paginator.upToDate) await this.#paginator.resetToLastPage()
  }

  async returnToLatest() {
    this.latestTarget.hidden = true
    await this.#paginator.resetToLastPage()
    this.#scrollManager.autoscroll(true)
  }

  // Callbacks

  #upToDateChanged(upToDate) {
    if (upToDate && this.latestTarget) this.latestTarget.hidden = true
  }

  // Private

  // A reset-then-broadcast race can deliver an already-rendered message:
  // skip appends whose rows are all present instead of duplicating them.
  #alreadyRendered(stream) {
    const template = stream.querySelector("template")
    if (!template) return false
    const ids = Array.from(template.content.querySelectorAll("[id^='message_']"))
      .map((el) => el.id)
      .filter((id) => /^message_\d+$/.test(id))
    return ids.length > 0 &&
      ids.every((id) => this.messagesTarget.querySelector(`#${CSS.escape(id)}`))
  }
}

function nextFrame() {
  return new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)))
}
