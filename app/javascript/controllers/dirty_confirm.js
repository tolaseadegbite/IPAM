// Shared dirty-form guard for native <dialog> modals. Snapshot the form
// state when a dialog opens; on any dismiss path, show an inline
// confirm bar instead of closing when something changed. File inputs
// are excluded (values can't be compared reliably).
const EXCLUDED_TYPES = new Set([ "hidden", "submit", "button", "file" ])

const fieldKey = (el, index) => el.name || `${el.tagName}:${el.type}:${index}`

export function snapshotDialog(dialog) {
  const state = new Map()
  dialog.querySelectorAll("input, select, textarea").forEach((el, index) => {
    if (EXCLUDED_TYPES.has(el.type)) return
    state.set(fieldKey(el, index), fieldValue(el))
  })
  return state
}

export function dialogIsDirty(dialog, snapshot) {
  let dirty = false
  dialog.querySelectorAll("input, select, textarea").forEach((el, index) => {
    if (EXCLUDED_TYPES.has(el.type)) return
    if (fieldValue(el) !== snapshot.get(fieldKey(el, index))) dirty = true
  })
  return dirty
}

function fieldValue(el) {
  if (el.type === "checkbox" || el.type === "radio") return el.checked ? "1" : "0"
  if (el.tagName === "SELECT" && el.multiple) {
    return [ ...el.selectedOptions ].map((o) => o.value).join(",")
  }
  return el.value ?? ""
}

// Shows (or reuses) an inline confirm bar at the top of the dialog.
// onDiscard runs only when the user confirms.
export function confirmDiscardIfDirty(dialog, snapshot, onDiscard) {
  if (!dialogIsDirty(dialog, snapshot)) {
    onDiscard()
    return
  }
  if (dialog.querySelector("[data-dirty-confirm]")) return
  const bar = document.createElement("div")
  bar.setAttribute("data-dirty-confirm", "")
  bar.className = "mb-4 flex flex-wrap items-center justify-between gap-2 rounded-lg border border-amber-300 bg-amber-50 p-3 text-sm dark:border-amber-500/30 dark:bg-amber-500/10"
  bar.innerHTML = `
    <span class="font-medium text-amber-800 dark:text-amber-200">You have unsaved changes.</span>
    <span class="flex gap-2">
      <button type="button" class="btn !px-3 !py-1.5 text-sm" data-dirty-keep>Keep editing</button>
      <button type="button" class="btn btn--negative !px-3 !py-1.5 text-sm" data-dirty-discard>Discard</button>
    </span>`
  const content = dialog.querySelector(".dialog__content") || dialog
  content.prepend(bar)
  bar.querySelector("[data-dirty-keep]").addEventListener("click", () => bar.remove(), { once: true })
  bar.querySelector("[data-dirty-discard]").addEventListener("click", () => onDiscard(), { once: true })
}
