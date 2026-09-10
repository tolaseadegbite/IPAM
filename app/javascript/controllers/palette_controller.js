import { Controller } from "@hotwired/stimulus"

const DEBOUNCE_MS = 150

const escapeHtml = (value) =>
  String(value ?? "").replace(/[&<>"']/g, (char) => (
    { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[char]
  ))

// Cmd/Ctrl+K command palette: fuzzy-navigates inventory plus static
// commands. Desktop only; mobile uses the bottom tab bar.
export default class extends Controller {
  static targets = ["dialog", "input", "results"]

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
      Turbo.visit(active.dataset.url)
      this.close()
    }
  }

  #onKeydown(event) {
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
      event.preventDefault()
      this.open()
    }
  }

  async #search(query) {
    const response = await fetch(`/palette?q=${encodeURIComponent(query)}`, {
      headers: { Accept: "application/json" }
    })
    if (!response.ok) return
    const results = await response.json()
    this.resultsTarget.innerHTML = results.map((result, index) => `
      <button type="button" data-url="${escapeHtml(result.url)}" data-action="click->palette#visit"
              data-palette-index="${index}"
              class="palette-item menu__item w-full ${index === 0 ? "is-active" : ""}">
        <svg class="h-4 w-4 shrink-0 text-zinc-400" aria-hidden="true"><use href="#icon-${escapeHtml(result.icon)}"></use></svg>
        <span class="min-w-0 flex-1 text-left">
          <span class="block truncate font-medium">${escapeHtml(result.label)}</span>
          ${result.sub ? `<span class="block truncate text-xs text-zinc-500">${escapeHtml(result.sub)}</span>` : ""}
        </span>
      </button>`).join("")
  }

  visit(event) {
    const url = event.currentTarget.dataset.url
    this.close()
    Turbo.visit(url)
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
