import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    nextPage: Number,
    lastPage: Number,
    loading: { type: Boolean, default: false }
  }

  connect() {
    this.observer = new IntersectionObserver(entries => {
      if (entries[0].isIntersecting && !this.loadingValue && this.nextPageValue <= this.lastPageValue) {
        this.#loadNextPage()
      }
    }, { rootMargin: "200px" })
    this.observer.observe(this.element)
  }

  disconnect() {
    this.observer?.disconnect()
  }

  async #loadNextPage() {
    this.loadingValue = true
    try {
      const url = `${window.location.pathname}?page=${this.nextPageValue}`
      const response = await fetch(url, {
        headers: { Accept: "text/vnd.turbo-stream.html" }
      })
      if (response.ok) {
        Turbo.renderStreamMessage(await response.text())
      }
    } finally {
      this.loadingValue = false
    }
  }
}
