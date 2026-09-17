// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// A frame navigation that answers without the expected frame (stale
// params, raced responses) would otherwise leave a dead "Content missing"
// panel. Fall back to a full-page visit so the worst case is a working
// page instead of a cryptic error box.
document.addEventListener("turbo:frame-missing", (event) => {
  event.preventDefault()
  event.detail.visit(event.detail.response.url)
})
