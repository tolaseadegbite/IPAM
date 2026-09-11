import { Controller } from "@hotwired/stimulus"

const DEBOUNCE_MS = 150

const escapeHtml = (value) =>
  String(value ?? "").replace(/[&<>"']/g, (char) => (
    { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[char]
  ))

// Cmd/Ctrl+K command palette: fuzzy-navigates inventory plus static
// commands. Desktop only; mobile uses the bottom tab bar.
//
// Direct hotkeys: Ctrl/Cmd+Shift+letter jumps straight to a top
// destination with no palette. Only mapped letters are intercepted
// (everything else passes through untouched), and never while typing
// in a field or while the palette itself is open. Destinations come
// from the server (goTo value) so they track route changes.
export default class extends Controller {
  static targets = ["dialog", "input", "results"]
  static values = { goTo: Object }

  #debouncedSearch = null
  #boundKeydown = null

  connect() {
    this.#boundKeydown = this.#onKeydown.bind(this)
    window.addEventListener("keydown", this.#boundKeydown)
  }

  disconnect() {
    window.removeEventListener("keydown", this.#boundKeydown)
    clearTimeout(this.#debouncedSearch)
  }

  open() {
    this.dialogTarget.showModal()
    this.inputTarget.value = ""
    this.#search("")
    this.inputTarget.focus()
  }

  close() {
    if (this.dialogTarget.open) this.dialogTarget.close()
  }

  closeOnClickOutside(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  search() {
    clearTimeout(this.#debouncedSearch)
    this.#debouncedSearch = setTimeout(() => this.#search(this.inputTarget.value), DEBOUNCE_MS)
  }

  navigate(event) {
    const items = this.#items()
    if (items.length === 0) return

    if (event.key === "ArrowDown") {
      event.preventDefault()
      this.#activate((this.#activeIndex() + 1) % items.length)
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.#activate((this.#activeIndex() - 1 + items.length) % items.length)
    } else if (event.key === "Enter") {
      const active = items[this.#activeIndex()] || items[0]
      this.#follow(active)
    }
  }

  #onKeydown(event) {
    if ((event.metaKey || event.ctrlKey) && !event.shiftKey && event.key.toLowerCase() === "k") {
      event.preventDefault()
      this.open()
      return
    }

    if (!(event.metaKey || event.ctrlKey) || !event.shiftKey || event.altKey) return
    if (this.dialogTarget.open) return
    if (this.#typing(event)) return

    const url = this.goToValue[event.key.toLowerCase()]
    if (url) {
      event.preventDefault()
      Turbo.visit(url)
    }
  }

  #typing(event) {
    const target = event.target
    return target instanceof HTMLElement &&
      (target.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(target.tagName))
  }

  async #search(query) {
    const response = await fetch(`/palette?q=${encodeURIComponent(query)}`, {
      headers: { Accept: "application/json" }
    })
    if (!response.ok) return
    const results = await response.json()
    let lastSection = null
    this.resultsTarget.innerHTML = results.map((result, index) => {
      const header = result.section && result.section !== lastSection
        ? `<div class="menu__header text-zinc-500" role="presentation">${escapeHtml(result.section)}</div>`
        : ""
      lastSection = result.section || lastSection
      return `${header}
      <button type="button" data-url="${escapeHtml(result.url)}" ${result.method ? `data-method="${escapeHtml(result.method)}"` : ""} data-action="click->palette#visit"
              data-palette-index="${index}"
              class="palette-item menu__item w-full ${index === 0 ? "is-active" : ""}">
        <svg class="h-4 w-4 shrink-0 text-zinc-400" aria-hidden="true">${result.icon ? `<use href="#icon-${escapeHtml(result.icon)}"></use>` : ""}</svg>
        <span class="min-w-0 flex-1 text-left">
          <span class="block truncate font-medium">${escapeHtml(result.label)}</span>
          ${result.sub ? `<span class="block truncate text-xs text-zinc-500">${escapeHtml(result.sub)}</span>` : ""}
        </span>
      </button>`
    }).join("")
  }

  visit(event) {
    this.#follow(event.currentTarget)
  }

  // GET results navigate; POST results (e.g. Scan now) submit in place —
  // the server answers head :ok and updates the page over Turbo Streams.
  #follow(item) {
    this.close()
    if (item.dataset.method === "post") {
      const token = document.querySelector("meta[name='csrf-token']")?.content
      fetch(item.dataset.url, {
        method: "POST",
        headers: { "X-CSRF-Token": token, Accept: "text/vnd.turbo-stream.html" }
      })
    } else {
      Turbo.visit(item.dataset.url)
    }
  }

  #items() {
    return [ ...this.resultsTarget.querySelectorAll("[data-palette-index]") ]
  }

  #activeIndex() {
    const items = this.#items()
    return Math.max(0, items.findIndex((item) => item.classList.contains("is-active")))
  }

  #activate(index) {
    this.#items().forEach((item, i) => item.classList.toggle("is-active", i === index))
    this.#items()[index]?.scrollIntoView({ block: "nearest" })
  }
}
