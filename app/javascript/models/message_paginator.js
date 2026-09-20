// Paginated history loader: observes the first and last rows of the
// message list and fetches older/newer windows by message-id cursor.
// Ported from Campfire's message_paginator, adapted: native fetch instead
// of @rails/request.js, row cursors parsed from message_<id> element ids
// (no partial changes required), no client-side formatter (rows arrive
// server-rendered).
import {
  insertHTMLFragment,
  parseHTMLFragment,
  keepScroll,
  trimChildren
} from "helpers/dom_helpers"

const MAX_MESSAGES = 320
const TRIM_LEEWAY = 20
const ROW_SELECTOR = "[id^='message_']"
// The pending-reply skeleton shares the message_ id prefix but is UI
// chrome, not history: never count, observe, or trim it.
const HISTORY_ROW_SELECTOR = "[id^='message_']:not([id^='message_skeleton_'])"

function cursorFor(element) {
  const match = element?.id?.match(/^message_(\d+)$/)
  return match ? match[1] : null
}

class ScrollTracker {
  #container
  #callback
  #intersectionObserver
  #mutationObserver
  #firstChildWasHidden

  constructor(container, callback) {
    this.#container = container
    this.#callback = callback
    this.#intersectionObserver = new IntersectionObserver(this.#handleIntersection.bind(this), { root: container, rootMargin: "200px" })
    this.#mutationObserver = new MutationObserver(this.#childrenChanged.bind(this))

    this.#mutationObserver.observe(container, { childList: true })
  }

  connect() {
    this.#childrenChanged()
  }

  disconnect() {
    this.#intersectionObserver.disconnect()
  }

  #rows() {
    return Array.from(this.#container.querySelectorAll(HISTORY_ROW_SELECTOR))
      .filter((el) => cursorFor(el))
  }

  #childrenChanged() {
    this.disconnect()

    const rows = this.#rows()
    if (rows.length > 0) {
      this.#firstChildWasHidden = false

      this.#intersectionObserver.observe(rows[0])
      this.#intersectionObserver.observe(rows[rows.length - 1])
    }
  }

  #handleIntersection(entries) {
    for (const entry of entries) {
      const rows = this.#rows()
      const isFirst = entry.target === rows[0]
      // Don't callback when the first row is shown unless it had previously
      // been hidden: freshly prepended pages always fire for the first row
      // before the scroll position is adjusted.
      const significantReveal = (isFirst && this.#firstChildWasHidden) || !isFirst

      if (entry.isIntersecting) {
        if (significantReveal) {
          this.#callback(entry.target)
        }
      } else {
        if (isFirst) {
          this.#firstChildWasHidden = true
        }
      }
    }
  }
}

export default class MessagePaginator {
  #container
  #url
  #upToDateCallback
  #scrollTracker
  #upToDate = true

  constructor(container, url, upToDateCallback) {
    this.#container = container
    this.#url = url
    this.#upToDateCallback = upToDateCallback
    this.#scrollTracker = new ScrollTracker(container, this.#rowBecameVisible.bind(this))
  }

  monitor() {
    this.#scrollTracker.connect()
  }

  disconnect() {
    this.#scrollTracker.disconnect()
  }

  get upToDate() {
    return this.#upToDate
  }

  async resetToLastPage() {
    this.upToDate = true
    const response = await fetch(this.#url, { headers: { Accept: "text/html" } })
    if (response.ok) {
      this.#container.replaceChildren(parseHTMLFragment(await response.text()))
    }
  }

  async trimExcessMessages(top) {
    const count = this.#container.querySelectorAll(HISTORY_ROW_SELECTOR).length
    const overage = count - MAX_MESSAGES
    if (overage > TRIM_LEEWAY) {
      trimChildren(overage, this.#container, top, HISTORY_ROW_SELECTOR)
      if (!top) {
        this.upToDate = false
      }
    }
  }

  set upToDate(value) {
    this.#upToDate = value
    this.#upToDateCallback?.(value)
  }

  #rowBecameVisible(element) {
    const messageId = cursorFor(element)
    const rows = Array.from(this.#container.querySelectorAll(HISTORY_ROW_SELECTOR))
      .filter((el) => cursorFor(el))
    const firstRow = Array.from(rows).find((el) => cursorFor(el))
    const lastRow = Array.from(rows).findLast((el) => cursorFor(el))
    const isFirst = element === firstRow
    const isLast = element === lastRow

    if (messageId) {
      if (isFirst) {
        this.#addPage({ before: messageId }, true)
      }
      if (isLast && !this.upToDate) {
        this.#addPage({ after: messageId }, false)
      }
    }
  }

  async #addPage(params, top) {
    const url = new URL(this.#url, window.location.origin)
    for (const param in params) {
      url.searchParams.set(param, params[param])
    }

    const response = await fetch(url, { headers: { Accept: "text/html" } })
    if (response.status === 204) {
      if (!top) this.upToDate = true
      return
    }
    if (!response.ok) return

    const page = parseHTMLFragment(await response.text())
    const rowCount = page.querySelectorAll(ROW_SELECTOR).length
    if (rowCount === 0) {
      if (!top) this.upToDate = true
      return
    }

    keepScroll(this.#container, top, () => {
      insertHTMLFragment(page, this.#container, top)
    })

    this.trimExcessMessages(!top)
  }
}
