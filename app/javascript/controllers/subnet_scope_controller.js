import { Controller } from "@hotwired/stimulus"

// Guides subnet pickers toward the selected department's branch: options
// from other branches hide, while the current selection and branch-less
// (shared) pools always stay. Guidance only — the server accepts any
// branch, so overrides and cross-branch history keep working.
export default class extends Controller {
  static targets = ["department", "filter"]

  initialize() {
    this.reapply = this.reapply.bind(this)
  }

  connect() {
    document.addEventListener("turbo:frame-load", this.reapply)
    this.apply()
  }

  disconnect() {
    document.removeEventListener("turbo:frame-load", this.reapply)
  }

  filter() {
    this.apply()
  }

  // Department options reload through their own frame on branch change;
  // re-scope once the fresh options land.
  reapply(event) {
    if (event && event.target.id !== "department_options_frame") return

    this.apply()
  }

  apply() {
    const selected = this.hasDepartmentTarget ? this.departmentTarget.selectedOptions[0] : null
    const branchId = selected?.dataset.branchId || ""

    this.filterTargets.forEach((select) => {
      const current = select.value
      ;[...select.options].forEach((option) => {
        if (!option.value) return
        const shared = !option.dataset.branchId
        const sticky = option.value === current
        option.hidden = Boolean(branchId) && !shared && !sticky && option.dataset.branchId !== branchId
      })
    })
  }
}
