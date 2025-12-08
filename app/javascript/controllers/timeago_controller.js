import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { date: String }

  connect() {
    this.update()
    // Run this logic every 30 seconds to keep it fresh
    this.timer = setInterval(() => this.update(), 30000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  update() {
    if (!this.dateValue) return

    const date = new Date(this.dateValue)
    const now = new Date()
    const diffInSeconds = Math.floor((now - date) / 1000)

    let text = ""

    if (diffInSeconds < 60) {
      text = "less than a minute ago"
    } else if (diffInSeconds < 120) {
      text = "1 minute ago"
    } else if (diffInSeconds < 3600) {
      const minutes = Math.floor(diffInSeconds / 60)
      text = `${minutes} minutes ago`
    } else if (diffInSeconds < 7200) {
      text = "about 1 hour ago"
    } else {
      const hours = Math.floor(diffInSeconds / 3600)
      text = `about ${hours} hours ago`
    }

    this.element.textContent = text
  }
}