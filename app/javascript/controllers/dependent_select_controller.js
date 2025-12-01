import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "frame"]
  static values = { url: String }

  connect() {
    console.log("Dependent select connected")
  }

  load() {
    const branchId = this.selectTarget.value
    
    // Construct the URL with the selected branch_id
    // e.g. /departments/select_options?branch_id=5
    const url = new URL(this.urlValue, window.location.href)
    url.searchParams.set("branch_id", branchId)
    
    // Tell the Turbo Frame to reload from this URL
    this.frameTarget.src = url.toString()
  }
}