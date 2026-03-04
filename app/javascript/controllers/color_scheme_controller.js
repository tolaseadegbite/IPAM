import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.dataset.colorScheme = this.#colorScheme
  }

  setLight() {
    this.setColorScheme("light")
  }

  setDark() {
    this.setColorScheme("dark")
  }

  setSystem() {
    this.setColorScheme("system")
  }

  setColorScheme(scheme) {
    this.element.dataset.colorScheme = scheme
    localStorage.setItem("color_scheme", scheme)
    
    // NEW: Set a cookie so the server knows the preference
    document.cookie = `color_scheme=${scheme}; path=/; max-age=31536000`
  }

  get #colorScheme() {
    return localStorage.getItem("color_scheme") || "system"
  }
}