import { Controller } from "@hotwired/stimulus"

// Escape flips the Plan/Build mode by clicking whichever option is
// currently inactive. Skipped while a modal dialog or popover owns the
// keyboard, so Esc keeps its dismiss meaning there.
export default class extends Controller {
  // Mode pills are plain type="button" elements (never nested forms), so a
  // click PATCHes the chat via fetch and reloads into the new mode.  Failure
  // leaves the toggle untouched (never a silent wrong state).
  switch(event) {
    const { mode, url } = event.params
    if (!mode || !url) return

    const token = document.querySelector('meta[name="csrf-token"]')?.content
    fetch(url, {
      method: "PATCH",
      headers: { "X-CSRF-Token": token, "Accept": "text/html" },
      body: new URLSearchParams({ "chat[mode]": mode })
    }).then((response) => {
      if (response.ok) {
        window.location.reload()
      } else {
        console.error("Mode switch failed:", response.status)
      }
    }).catch((error) => console.error("Mode switch failed:", error))
  }

  escape(event) {
    if (event.key !== "Escape" && event.key !== "Esc") return
    if (event.defaultPrevented) return
    if (document.querySelector("dialog[open]")) return
    if (document.querySelector(".popover:popover-open")) return

    const inactive = this.element.querySelector('button[aria-pressed="false"]')
    if (inactive) {
      event.preventDefault()
      inactive.click()
    }
  }
}
