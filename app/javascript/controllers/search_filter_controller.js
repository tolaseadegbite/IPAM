import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["filters"]

  toggle() {
    this.filtersTarget.classList.toggle("hide")
  }

  closeOnClickOutside(event) {
    const isOutside = !this.element.contains(event.target)
    const isVisible = !this.filtersTarget.classList.contains("hide")
    // Check if the click is on a submit button or the clear link inside the form
    const isActionInside = this.filtersTarget.contains(event.target)

    if (isOutside && isVisible && !isActionInside) {
      this.filtersTarget.classList.add("hide")
    }
  }

  // NEW: Clears all inputs visually
  clear(event) {
    // The link will handle the Turbo Request to reset the table.
    // We just need to empty the UI fields.
    
    const inputs = this.filtersTarget.querySelectorAll("input, select")
    
    inputs.forEach((input) => {
      // Don't clear hidden fields (like authenticity_token) or submit buttons
      if (input.type === "hidden" || input.type === "submit") return
      
      input.value = ""
    })
  }
}