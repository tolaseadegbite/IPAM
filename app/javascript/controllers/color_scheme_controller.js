import { Controller } from "@hotwired/stimulus"

// Toggles the `dark` class on <html> for Tailwind's class-based dark mode,
// plus an optional Omarchy theme via `data-theme` (CSS variable overrides).
// Both persist in localStorage + cookies (server reads them for first paint).
export default class extends Controller {
  connect() {
    this.apply(this.#colorScheme, this.#theme)
    this.#syncActiveItems()
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

  setTheme(event) {
    const theme = event.params.theme
    if (!theme) return

    localStorage.setItem("theme", theme)
    document.cookie = `theme=${theme}; path=/; max-age=31536000`
    // Every bundled theme is dark-mode only.
    localStorage.setItem("color_scheme", "dark")
    document.cookie = `color_scheme=dark; path=/; max-age=31536000`
    this.apply("dark", theme)
    this.#syncActiveItems()
    window.dispatchEvent(new CustomEvent("app:theme-change"))
  }

  setColorScheme(scheme) {
    localStorage.setItem("color_scheme", scheme)
    document.cookie = `color_scheme=${scheme}; path=/; max-age=31536000`
    // Themes only exist in dark mode; leaving it drops back to stock.
    if (scheme !== "dark") this.#clearTheme()
    this.apply(scheme, this.#theme)
    this.#syncActiveItems()
  }

  apply(scheme, theme) {
    const dark =
      scheme === "dark" ||
      (scheme === "system" && window.matchMedia("(prefers-color-scheme: dark)").matches)
    document.documentElement.classList.toggle("dark", dark)
    if (theme && dark) {
      document.documentElement.dataset.theme = theme
    } else {
      delete document.documentElement.dataset.theme
    }
    this.element.dataset.colorScheme = scheme
  }

  #clearTheme() {
    localStorage.removeItem("theme")
    document.cookie = "theme=; path=/; max-age=0"
    delete document.documentElement.dataset.theme
    window.dispatchEvent(new CustomEvent("app:theme-change"))
  }

  // Highlights the current choice in the Theme menu: the base option when
  // stock, the theme entry when themed. Runs on boot too, so reloads and
  // server-rendered first paint stay in sync.
  #syncActiveItems() {
    const scheme = this.#colorScheme
    const theme = this.#theme
    document.querySelectorAll("[data-appearance-option]").forEach((el) => {
      el.classList.toggle("is-active", el.dataset.appearanceOption === scheme && !theme)
    })
    document.querySelectorAll("[data-color-scheme-theme-param]").forEach((el) => {
      el.classList.toggle("is-active", el.dataset.colorSchemeThemeParam === theme)
    })
  }

  get #colorScheme() {
    return localStorage.getItem("color_scheme") || "system"
  }

  get #theme() {
    return localStorage.getItem("theme")
  }
}
