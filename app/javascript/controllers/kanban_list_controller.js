import { Controller } from "@hotwired/stimulus"

// Column drag-and-drop owned end to end on Pointer Events (no library).
// The defining property: pointer capture guarantees the release is
// delivered to us, so a drop can never die silently the way the
// previous library-based implementation did. Every exit path is
// explicit: persist on drop, snapshot-restore on abort, toast on error.
//
// NOTE: `gesture` (not `drag`) holds the in-flight state — `drag` would
// shadow the `drag(event)` action method and break dispatch.
export default class extends Controller {
  static values = { url: String }

  connect() {
    this.gesture = null
    this.onKeydown = (event) => {
      if (event.key === "Escape") this.cancel()
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
    // Never strand a lifted column or placeholder if the DOM goes away
    // mid-gesture (frame reload, morph).
    const current = this.gesture
    this.gesture = null
    if (current && current.started) {
      current.placeholder?.remove()
      this.undock(current)
      current.column.classList.remove("is-dragging")
    }
  }

  // -- Pointer drag ---------------------------------------------------

  grab(event) {
    // One press owns the gesture: a compat mouse event following its
    // pointer event must not restart it. Pointer Events are primary;
    // legacy mouse events backstop environments without them.
    if (this.gesture) return
    // Primary button only, from the handle, never from links or buttons
    // inside it (rename, delete, nudge).
    if (event.button !== 0) return
    if (event.target.closest("a, button")) return
    const column = event.target.closest(".kanban-column")
    if (!column || !this.element.contains(column)) return

    this.gesture = {
      column,
      pointerId: event.pointerId ?? "mouse",
      startX: event.clientX,
      startY: event.clientY,
      started: false,
      snapshot: this.order(),
      placeholder: null
    }
    try { this.element.setPointerCapture(event.pointerId) } catch {
      // No active pointer (synthetic events) — the gesture still works,
      // only release-outside-the-window delivery is degraded.
    }
  }

  drag(event) {
    const current = this.gesture
    if (!current || (event.pointerId ?? "mouse") !== current.pointerId) return
    if (!current.started) {
      if (Math.abs(event.clientX - current.startX) < 4) return
      this.begin(current)
    }
    this.followPointer(current, event.clientX, event.clientY)
    this.movePlaceholder(current, event.clientX)
  }

  drop(event) {
    const current = this.gesture
    if (!current || (event.pointerId ?? "mouse") !== current.pointerId) return
    this.finish(false)
  }

  cancel() {
    this.finish(true)
  }

  // -- Nudge buttons (deterministic, pointer-free reorder) ------------

  nudge(event) {
    event.preventDefault()
    const siblings = this.columns()
    const index = siblings.map((element) => element.dataset.listId).indexOf(String(event.params.id))
    const target = index + (event.params.direction === "forward" ? 1 : -1)
    if (index < 0 || target < 0 || target >= siblings.length) return
    // Optimistic glide: the server morph confirms the same order.
    this.flip(() => {
      const moving = siblings[index]
      if (event.params.direction === "forward") {
        this.element.insertBefore(moving, siblings[target].nextSibling)
      } else {
        this.element.insertBefore(moving, siblings[target])
      }
    })
    this.save(String(event.params.id), target + 1)
  }

  // -- Internals ------------------------------------------------------

  // FLIP list animation: snapshot first positions, mutate, invert the
  // delta with a transform, then play it off. Mutations land instantly
  // for reduced-motion users (no invert/play). The held column is
  // excluded: its own settle transition (tilt easing flat) owns it.
  flip(mutator) {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      mutator()
      return
    }
    const first = new Map()
    this.columns().forEach((element) => {
      if (element.classList.contains("is-dragging")) return
      first.set(element, element.getBoundingClientRect().left)
    })
    mutator()
    this.columns().forEach((element) => {
      const start = first.get(element)
      if (start === undefined) return
      const delta = start - element.getBoundingClientRect().left
      if (!delta) return
      element.style.transition = "none"
      element.style.transform = `translateX(${delta}px)`
      const cleanup = () => {
        element.style.transition = ""
        element.style.transform = ""
      }
      element.addEventListener("transitionend", cleanup, { once: true })
      requestAnimationFrame(() => {
        element.style.transition = "transform 170ms ease-out"
        element.style.transform = ""
      })
    })
  }

  order() {
    return [...this.element.querySelectorAll(":scope > .kanban-column")]
      .map((element) => element.dataset.listId)
  }

  columns() {
    return [...this.element.querySelectorAll(":scope > .kanban-column")]
  }

  begin(current) {
    current.started = true
    document.addEventListener("keydown", this.onKeydown)

    const rect = current.column.getBoundingClientRect()

    const placeholder = document.createElement("div")
    placeholder.className = "kanban-drop-placeholder w-80 shrink-0 rounded-xl border-2 border-dashed border-orange-400/70"
    placeholder.style.height = `${rect.height}px`
    placeholder.setAttribute("aria-hidden", "true")
    current.column.before(placeholder)
    current.placeholder = placeholder

    // Lift out of flow: the placeholder holds the slot while the column
    // itself follows the pointer (Trello-style).
    Object.assign(current.column.style, {
      position: "fixed",
      left: `${rect.left}px`,
      top: `${rect.top}px`,
      width: `${rect.width}px`,
      margin: "0",
      zIndex: 50
    })
    current.column.classList.add("is-dragging")
    this.followPointer(current, current.startX, current.startY)
  }

  followPointer(current, clientX, clientY) {
    const dx = clientX - current.startX
    const dy = clientY - current.startY
    current.column.style.transform = `translate(${dx}px, ${dy}px) rotate(2.5deg) scale(1.03)`
  }

  movePlaceholder(current, clientX) {
    if (current.flipQueued) return
    current.flipQueued = true
    requestAnimationFrame(() => {
      current.flipQueued = false
      // A new gesture may have replaced this one while queued.
      if (this.gesture !== current) return
      this.flip(() => this.placePlaceholder(current, current.pointerX ?? clientX))
    })
    current.pointerX = clientX
  }

  placePlaceholder(current, clientX) {
    const siblings = this.columns()
      .filter((element) => element !== current.column && element !== current.placeholder)
    for (const element of siblings) {
      const rect = element.getBoundingClientRect()
      if (clientX < rect.left + rect.width / 2) {
        this.element.insertBefore(current.placeholder, element)
        return
      }
    }
    this.element.appendChild(current.placeholder)
  }

  finish(cancelled) {
    const current = this.gesture
    if (!current) return
    this.gesture = null
    document.removeEventListener("keydown", this.onKeydown)
    try { this.element.releasePointerCapture(current.pointerId) } catch {
      // Capture already released (teardown) — nothing to do.
    }
    if (!current.started) return // plain click, e.g. header whitespace

    this.undock(current)
    this.flip(() => {
      current.placeholder.replaceWith(current.column)
      current.column.classList.remove("is-dragging")
    })

    if (cancelled) {
      this.flip(() => this.restore(current.snapshot))
      return
    }

    const now = this.order()
    if (now.join() === current.snapshot.join()) return // dropped back home
    this.save(current.column.dataset.listId, now.indexOf(current.column.dataset.listId) + 1)
  }

  // Return the held column to normal flow before it re-enters layout.
  undock(current) {
    Object.assign(current.column.style, {
      position: "",
      left: "",
      top: "",
      width: "",
      margin: "",
      zIndex: "",
      transform: ""
    })
  }

  restore(snapshot) {    const byId = new Map(this.columns().map((element) => [element.dataset.listId, element]))
    snapshot.forEach((id) => {
      const element = byId.get(id)
      if (element) this.element.appendChild(element)
    })
  }

  save(listId, position) {
    const url = this.urlValue.replace(":id", listId)
    fetch(url, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfToken()
      },
      body: JSON.stringify({ position })
    }).then((response) => {
      if (!response.ok) this.revert(response)
    })
  }

  csrfToken() {
    const token = document.querySelector("meta[name='csrf-token']")?.content
      || document.querySelector("[name='csrf-token']")?.content
    if (!token) console.error("[kanban-list] CSRF meta tag missing; move PATCH will fail.")
    return token
  }

  // The server rejected the move: show the error and restore server
  // truth so the board never lies.
  async revert(response) {
    let message = "Could not move column."
    try {
      const body = await response.json()
      if (body?.errors) message = body.errors
    } catch {
      // Non-JSON failure — keep the generic message.
    }
    this.notify(message)

    const frame = document.getElementById("board_results")
    if (frame) {
      frame.reload()
    } else {
      Turbo.visit(window.location.href, { action: "replace" })
    }
  }

  notify(message) {
    const host = document.getElementById("flash_messages")
    if (!host) return
    const flash = document.createElement("div")
    flash.className = "flash flash--negative"
    flash.dataset.controller = "flash"
    const content = document.createElement("div")
    content.className = "flash__content"
    content.textContent = message
    flash.appendChild(content)
    host.appendChild(flash)
  }
}
