import { Controller } from "@hotwired/stimulus"

// Owns collapsible filter panels: toggle, and resets that clear
// fields and resubmit in place WITHOUT collapsing the panel or
// navigating away, so another search is one keystroke away.
// Toggle-only: the panel opens/closes via the button alone — no
// click-outside dismissal — so in-place actions (Clear all, pill
// dismiss) never collapse it.
export default class extends Controller {
  static targets = ["filters"]

  toggle() {
    if (!this.hasFiltersTarget) return
    this.filtersTarget.classList.toggle("hidden")
  }

  // Clears every field (widget-aware) and resubmits once. Panel state
  // is intentionally left untouched.
  resetAll(event) {
    event.preventDefault()
    this.#fieldRoots().forEach((root) => {
      root.querySelectorAll("input, select, textarea").forEach((el) => this.#clearField(el))
    })
    this.#submitSearch()
  }

  // Clears the filter(s) named in `names` (space-separated input names),
  // then submits once. Used by per-pill dismiss buttons. Falls back to
  // the main page search form when the pills live outside the panel
  // controller scope (pills render inside the Turbo Frame, the form
  // outside it), so dismissing a pill clears the matching field too.
  removeFilter(event) {
    event.preventDefault()
    const names = (event.params.names || "").split(" ").filter(Boolean)
    const scope = this.#clearScope()
    names.forEach((name) => {
      scope.querySelectorAll(`[name="${CSS.escape(name)}"]`).forEach((el) => this.#clearField(el))
    })
    this.#submitSearch()
  }

  // Legacy single-panel clear used by older links: clears fields but
  // does not navigate, so the panel stays exactly as it was.
  clear(event) {
    event.preventDefault()
    if (!this.hasFiltersTarget) {
      this.resetAll(event)
      return
    }
    const inputs = this.filtersTarget.querySelectorAll("input, select")

    inputs.forEach((input) => {
      // Skip hidden fields (CSRF tokens) and buttons
      if (input.type === "hidden" || input.type === "submit") return

      this.#clearField(input)
    })
    this.#submitSearch()
  }

  #clearScope() {
    // Prefer the local scope, but pills render inside the results
    // Turbo Frame while the form lives outside it — fall back to the
    // whole document so pill dismiss clears the real field.
    if (this.#searchForm()?.closest("[data-controller='search-filter']")) {
      return this.#searchForm().closest("[data-controller='search-filter']")
    }
    return document
  }

  #fieldRoots() {
    const searchForm = this.#searchForm()
    if (this.hasFiltersTarget) {
      const roots = [ this.filtersTarget ]
      if (searchForm && !this.filtersTarget.contains(searchForm)) roots.push(searchForm)
      return roots
    }
    return searchForm ? [ searchForm ] : [ document ]
  }

  #submitSearch() {
    const form = this.#searchForm()
    if (form) form.requestSubmit()
  }

  #searchForm() {
    return this.element.querySelector("form") || document.querySelector("[data-controller='search-filter'] form, form[data-turbo-frame]")
  }

  #clearField(el) {
    if (el._flatpickr) {
      el._flatpickr.clear()
      return
    }
    if (el.tomselect) {
      el.tomselect.clear()
      return
    }
    if (el.type === "checkbox" || el.type === "radio") {
      el.checked = false
      return
    }
    el.value = ""
  }
}
