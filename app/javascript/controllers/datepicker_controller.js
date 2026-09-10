import { Controller } from "@hotwired/stimulus"
import flatpickr from "flatpickr"

// Date/time picker (flatpickr, vendored). Usage:
//   <input data-controller="datepicker">                    -> date (Y-m-d)
//   <input data-controller="datepicker" data-datepicker-mode-value="datetime">
//   <input data-controller="datepicker" data-datepicker-mode-value="time">
// Exposes clear() so filter reset logic can empty pickers like trellixe's.
export default class extends Controller {
  static values = { mode: { type: String, default: "date" } }

  connect() {
    const options = { allowInput: true, disableMobile: true }

    if (this.modeValue === "datetime") {
      options.enableTime = true
      options.dateFormat = "Y-m-d H:i"
    } else if (this.modeValue === "time") {
      options.enableTime = true
      options.noCalendar = true
      options.dateFormat = "H:i"
    } else {
      options.dateFormat = "Y-m-d"
    }

    this.picker = flatpickr(this.element, options)
    this.element._flatpickr = this.picker
  }

  disconnect() {
    this.picker?.destroy()
    this.element._flatpickr = undefined
  }

  clear() {
    this.picker?.clear()
  }
}
