import { Controller } from "@hotwired/stimulus"

// Focused controller for currency input masking
export default class extends Controller {
  static targets = ["input"]

  connect() {
    if (this.hasInputTarget) {
      this.setupMask()
      this.formatInitialValue()
    }
  }

  disconnect() {
    if (this.inputTarget) {
      this.inputTarget.removeEventListener('input', this.handleInput)
    }
  }

  setupMask() {
    this.handleInput = this.applyMask.bind(this)
    this.inputTarget.addEventListener('input', this.handleInput)
  }

  formatInitialValue() {
    if (this.inputTarget.value && this.inputTarget.value.match(/\d/)) {
      const numericValue = MoneyFormatter.parse(this.inputTarget.value)
      this.inputTarget.value = MoneyFormatter.formatForInput(numericValue)
    }
  }

  applyMask(event) {
    MoneyFormatter.mask(event.target)
  }

  get numericValue() {
    return MoneyFormatter.getNumericValue(this.inputTarget)
  }
}
