import { Controller } from "@hotwired/stimulus"

/**
 * Balance Toggle Controller
 * Toggles visibility of accumulated balance column in transactions list
 * Following Orzeny principle: show/hide based on user preference
 */
export default class extends Controller {
  static targets = ["balance", "button"]

  connect() {
    // Load saved preference from localStorage
    const isVisible = localStorage.getItem('balanceVisible') === 'true'
    this.setVisibility(isVisible)
  }

  toggle() {
    const currentVisibility = this.element.dataset.balanceVisible === 'true'
    const newVisibility = !currentVisibility
    
    this.setVisibility(newVisibility)
    
    // Save preference
    localStorage.setItem('balanceVisible', newVisibility)
  }

  setVisibility(isVisible) {
    this.element.dataset.balanceVisible = isVisible
    
    if (this.hasButtonTarget) {
      this.buttonTarget.textContent = isVisible 
        ? '👁️ Ocultar Saldo' 
        : '👁️ Mostrar Saldo'
    }
  }
}
