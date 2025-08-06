import { Controller } from "@hotwired/stimulus"

// Focused controller for currency display formatting
export default class extends Controller {
  static targets = ["display"]
  static values = { amount: Number, showZero: Boolean }

  connect() {
    this.updateDisplay()
  }

  amountValueChanged() {
    this.updateDisplay()
  }

  updateDisplay() {
    if (this.hasDisplayTarget) {
      const formatted = this.showZeroValue || this.amountValue !== 0 
        ? MoneyFormatter.format(this.amountValue)
        : ''
      
      this.displayTarget.textContent = formatted
      this.updateCssClasses()
    }
  }

  updateCssClasses() {
    if (!this.hasDisplayTarget) return
    
    // Remove existing money classes
    this.displayTarget.classList.remove('money-positive', 'money-negative', 'money-neutral')
    
    // Add appropriate class based on amount
    if (this.amountValue > 0) {
      this.displayTarget.classList.add('money-positive')
    } else if (this.amountValue < 0) {
      this.displayTarget.classList.add('money-negative')
    } else {
      this.displayTarget.classList.add('money-neutral')
    }
  }

  // Update amount from external source
  update(newAmount) {
    this.amountValue = newAmount
  }
}
