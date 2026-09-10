import { Controller } from "@hotwired/stimulus"

// Owns native <details> disclosures that sit near the viewport bottom:
// when one opens, bring it into view above the fixed mobile bottom nav
// instead of leaving fresh content hidden behind it. No-op on close.
export default class extends Controller {
  opened(event) {
    if (event.target.open) {
      event.target.scrollIntoView({ block: "nearest" })
    }
  }
}
