import { Controller } from "@hotwired/stimulus"

// Toggles the `dark` class on <html> for Tailwind's class-based dark mode.
// Preference persists in localStorage + cookie (server reads it for first paint).
export default class extends Controller {
  connect() {
    this.apply(this.#colorScheme)
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
    localStorage.setItem("color_scheme", scheme)
    document.cookie = `color_scheme=${scheme}; path=/; max-age=31536000`
    this.apply(scheme)
  }

  apply(scheme) {
    const dark =
      scheme === "dark" ||
      (scheme === "system" && window.matchMedia("(prefers-color-scheme: dark)").matches)
    document.documentElement.classList.toggle("dark", dark)
    this.element.dataset.colorScheme = scheme
  }

  get #colorScheme() {
    return localStorage.getItem("color_scheme") || "system"
  }
}
