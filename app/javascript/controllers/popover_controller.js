import { Controller } from "@hotwired/stimulus"
// import { computePosition, flip, shift, offset, autoUpdate } from "https://esm.sh/@floating-ui/dom@1.7.2?standalone"

import { computePosition, flip, shift, offset, autoUpdate } from "@floating-ui/dom"

export default class extends Controller {
  static targets = [ "trigger", "content" ]
  static values  = { placement: { type: String, default: "bottom" } }

  #showTimer = null
  #hideTimer = null

  initialize() {
    this.orient = this.orient.bind(this)
  }

  connect() {
    this.cleanup = autoUpdate(this.triggerTarget, this.contentTarget, this.orient)
  }

  disconnect() {
    this.cleanup()
  }

  show() {
    this.contentTarget.showPopover()
  }

  hide() {
    this.contentTarget.hidePopover()
  }

  toggle() {
    // This uses the native toggle behavior.
    this.contentTarget.togglePopover()
  }

  // NEW: Method to handle clicks outside the component
  clickOutside(event) {
    // Check if the popover is currently open
    const isOpen = this.contentTarget.matches(":popover-open")

    // Check if the click happened outside the controller's element
    // this.element refers to the element with `data-controller="popover"`
    const isOutside = !this.element.contains(event.target)

    if (isOpen && isOutside) {
      this.hide()
    }
  }

  debouncedShow() {
    clearTimeout(this.#hideTimer)
    this.#showTimer = setTimeout(() => this.show(), 150)
  }

  debouncedHide() {
    clearTimeout(this.#showTimer)
    this.#hideTimer = setTimeout(() => this.hide(), 150)
  }

  orient() {
    computePosition(this.triggerTarget, this.contentTarget, this.#options).then(({x, y}) => {
      this.contentTarget.style.insetInlineStart = `${x}px`
      this.contentTarget.style.insetBlockStart  = `${y}px`
    })
  }

  get #options() {
    return { placement: this.placementValue, middleware: [offset(4), flip(), shift({padding: 4})] }
  }
}