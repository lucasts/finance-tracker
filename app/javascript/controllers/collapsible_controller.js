import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "icon"]
  
  connect() {
    // Start collapsed if no filters are active
    const hasActiveFilters = this.hasActiveFilters()
    if (!hasActiveFilters) {
      this.collapse()
    }
  }
  
  toggle() {
    if (this.contentTarget.classList.contains('hidden')) {
      this.expand()
    } else {
      this.collapse()
    }
  }
  
  expand() {
    this.contentTarget.classList.remove('hidden')
    this.iconTarget.classList.add('rotate-180')
  }
  
  collapse() {
    this.contentTarget.classList.add('hidden')
    this.iconTarget.classList.remove('rotate-180')
  }
  
  hasActiveFilters() {
    const url = new URL(window.location)
    const params = url.searchParams
    return params.has('account_id') || params.has('transaction_type') || params.has('month')
  }
}
