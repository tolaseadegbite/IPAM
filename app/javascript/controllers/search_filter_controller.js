import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["filters"]

  toggle() {
    this.filtersTarget.classList.toggle("hide")
  }

  closeOnClickOutside(event) {
    const isOutside = !this.element.contains(event.target)
    const isVisible = !this.filtersTarget.classList.contains("hide")
    const isActionInside = this.filtersTarget.contains(event.target)

    if (isOutside && isVisible && !isActionInside) {
      this.filtersTarget.classList.add("hide")
    }
  }

  // UPDATED: Handles text, selects, AND checkboxes correctly
  clear(event) {
    const inputs = this.filtersTarget.querySelectorAll("input, select")
    
    inputs.forEach((input) => {
      // Skip hidden fields (CSRF tokens) and buttons
      if (input.type === "hidden" || input.type === "submit") return
      
      if (input.type === "checkbox" || input.type === "radio") {
        input.checked = false
      } else {
        input.value = ""
      }
    })
  }
}