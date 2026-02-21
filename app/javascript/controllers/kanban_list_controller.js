import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static values = { url: String }

  connect() {
    this.sortable = Sortable.create(this.element, {
      animation: 150,
      handle: ".list-handle",      // Only drag if the user clicks the header
      draggable: ".kanban-column", // Prevents dragging the "Add List" button
      ghostClass: "opacity-50",    // Makes the dragged item semi-transparent
      onEnd: this.end.bind(this)
    })
  }

  disconnect() {
    this.sortable.destroy()
  }

  end(event) {
    // Grab the ID from the column we just dropped
    const listId = event.item.dataset.listId
    const newIndex = event.newIndex + 1 // acts_as_list is 1-based (starts at 1, not 0)
    
    // Construct the URL: /lists/:id/move
    const url = this.urlValue.replace(":id", listId)

    fetch(url, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content
      },
      body: JSON.stringify({ position: newIndex })
    })
  }
}