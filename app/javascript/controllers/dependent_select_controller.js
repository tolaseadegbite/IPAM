import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // We keep 'frame' in targets for backward compatibility
  static targets = ["select", "frame"]
  
  static values = { 
    url: String,
    param: { type: String, default: "branch_id" },
    extraParam: { type: String, default: "" },
    frameId: String // NEW: Allow finding frame by ID
  }

  load() {
    const id = this.selectTarget.value
    const url = new URL(this.urlValue, window.location.href)
    
    url.searchParams.set(this.paramValue, id)
    
    if (this.extraParamValue) {
      const [key, value] = this.extraParamValue.split("=")
      if (key && value) {
        url.searchParams.set(key, value)
      }
    }
    
    // LOGIC CHANGE: Prefer frameIdValue if provided, otherwise use target
    let frameElement
    if (this.hasFrameIdValue) {
      frameElement = document.getElementById(this.frameIdValue)
    } else {
      frameElement = this.frameTarget
    }

    if (frameElement) {
      frameElement.src = url.toString()
    } else {
      console.error("Dependent Select: No frame target found.")
    }
  }
}