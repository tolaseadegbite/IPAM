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
      onEnd: this.end.bind(this)
    })
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
        "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
      },
      body: JSON.stringify({
        list_id: newListId,
        position: newIndex
      })
    })
  }
}