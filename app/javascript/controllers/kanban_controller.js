import { Controller } from "@hotwired/stimulus"
// This now looks at vendor/javascript/sortablejs.js
import Sortable from "sortablejs"

export default class extends Controller {
  // Each List container will be a target
  static values = { url: String }

  connect() {
    this.sortable = Sortable.create(this.element, {
      group: 'kanban', // Allows dragging BETWEEN lists
      animation: 150,
      ghostClass: 'bg-yellow-100', // Visual style for the empty slot while dragging
      // Same protection as columns: title/asset links must not hijack
      // card gestures via native link-drags.
      filter: 'a, button',
      preventOnFilter: true,
      removeCloneOnHide: true,
      // Native HTML5 drag: proven working for cards. (forceFallback was
      // tried here and silently broke all card drops, so it stays off.
      // Column dragging uses the owned Pointer Events controller.)
      onEnd: this.end.bind(this)
    })
  }

  disconnect() {
    this.sortable?.destroy()
  }

  end(event) {
    const cardId = event.item.dataset.id
    const newListId = event.to.dataset.listId
    const newIndex = event.newIndex + 1 // Sortable is 0-based, acts_as_list is 1-based

    // Construct the URL: /cards/:id/move
    const url = this.urlValue.replace(":id", cardId)

    fetch(url, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.#csrfToken()
      },
      body: JSON.stringify({
        list_id: newListId,
        position: newIndex
      })
    })
  }

  #csrfToken() {
    const token = document.querySelector("meta[name='csrf-token']")?.content
      || document.querySelector("[name='csrf-token']")?.content
    if (!token) console.error("[kanban] CSRF meta tag missing; move PATCH will fail.")
    return token
  }

  // The server rejected the move but Sortable already moved the DOM node.
  // Show the error and restore server truth so the board never lies.
  async #revert(response) {
    let message = "Could not move task."
    try {
      const body = await response.json()
      if (body?.errors) message = body.errors
    } catch {
      // Non-JSON failure — keep the generic message.
    }
    this.#notify(message)

    const frame = document.getElementById("board_results")
    if (frame) {
      frame.reload()
    } else {
      Turbo.visit(window.location.href, { action: "replace" })
    }
  }

  #notify(message) {
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