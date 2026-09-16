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
    this.reorientOnToggle = this.reorientOnToggle.bind(this)
    this.dismissOnScroll = this.dismissOnScroll.bind(this)
  }

  connect() {
    this.cleanup = autoUpdate(this.triggerTarget, this.contentTarget, this.orient)
    this.contentTarget.addEventListener("toggle", this.reorientOnToggle)
    window.addEventListener("scroll", this.dismissOnScroll, { capture: true, passive: true })
  }

  disconnect() {
    this.contentTarget.removeEventListener("toggle", this.reorientOnToggle)
    window.removeEventListener("scroll", this.dismissOnScroll)
    this.cleanup()
  }

  // Coordinates computed while hidden (or pre-font-load) go stale fast.
  // Recompute at open time so the menu anchors to the live layout.
  reorientOnToggle() {
    if (this.contentTarget.matches(":popover-open")) this.orient()
  }

  // A menu that stays open while the page moves underneath reads as
  // broken (drifting/parallax). Dismiss on outside scroll instead;
  // scrolls originating inside the menu itself are ignored.
  dismissOnScroll(event) {
    if (!this.contentTarget.matches(":popover-open")) return
    if (this.contentTarget.contains(event.target)) return

    this.hide()
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
    // Top-layer popovers are viewport-fixed: coordinates must be
    // viewport-relative too ("absolute" bakes in scroll offset and the
    // menu drifts with the page). crossAxis shift keeps edge-anchored
    // menus (e.g. right-start in the sidebar) fully inside the viewport.
    return { placement: this.placementValue, strategy: "fixed", middleware: [offset(4), flip(), shift({ padding: 4, crossAxis: true })] }
  }
}