import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    if (this.hasInputTarget) {
      this.setupMask()
    }
  }

  disconnect() {
    // Remove listener to avoid leaks
    this.inputTarget.removeEventListener('input', this.nativeCurrencyMask)
    if (this.mask) this.mask.destroy()
  }

  setupMask() {
    // Remove IMask, implement simple native currency mask
    this.inputTarget.addEventListener('input', this.nativeCurrencyMask.bind(this))
    // When editing, format the initial value if present
    if (this.inputTarget.value && this.inputTarget.value.match(/\d/)) {
      this.formatInitialValue()
    } else {
      this.nativeCurrencyMask() // initialize
    }
  }

  formatInitialValue() {
    // Remove everything that is not a number, comma, or period
    let raw = this.inputTarget.value.replace(/[^\d,.]/g, '')
    // If it's already in Brazilian format (e.g., 123,45), just normalize it
    if (raw.match(/^\d{1,3}(\.\d{3})*,\d{2}$/)) {
      // E.g.: 1.234,56 → 1234,56
      raw = raw.replace(/\./g, '')
      this.inputTarget.value = raw
      this.nativeCurrencyMask()
      return
    }
    // If it's in American format (e.g., 123.45), convert it to Brazilian format
    if (raw.match(/^\d+\.\d{2}$/)) {
      raw = raw.replace('.', ',')
      this.inputTarget.value = raw
      this.nativeCurrencyMask()
      return
    }
    // If it's just an integer, multiply by 100 for cents
    if (raw.match(/^\d+$/)) {
      let value = raw.replace(/^0+(?!$)/, '')
      value = value.padStart(3, '0')
      let cents = value.slice(-2)
      let integer = value.slice(0, -2)
      integer = integer.replace(/^0+(?!$)/, '')
      if (integer.length === 0) integer = '0'
      integer = integer.replace(/\B(?=(\d{3})+(?!\d))/g, '.')
      this.inputTarget.value = integer + ',' + cents
      this.updateHelper()
      return
    }
    // fallback: tries to parse float
    let value = Math.round(parseFloat(raw.replace(',', '.')) * 100).toString()
    if (isNaN(value) || value === 'NaN') value = '0'
    value = value.replace(/^0+(?!$)/, '')
    value = value.padStart(3, '0')
    let cents = value.slice(-2)
    let integer = value.slice(0, -2)
    integer = integer.replace(/^0+(?!$)/, '')
    if (integer.length === 0) integer = '0'
    integer = integer.replace(/\B(?=(\d{3})+(?!\d))/g, '.')
    this.inputTarget.value = integer + ',' + cents
    this.updateHelper()
  }

  nativeCurrencyMask() {
    let value = this.inputTarget.value.replace(/\D/g, '')
    if (value.length === 0) value = '0'
    // Remove leading zeros, but keep at least 3 digits for cents
    value = value.replace(/^0+(?!$)/, '')
    value = value.padStart(3, '0')
    // Separate cents
    let cents = value.slice(-2)
    let integer = value.slice(0, -2)
    // Remove leading zeros from the integer part
    integer = integer.replace(/^0+(?!$)/, '')
    // Add thousand separator
    if (integer.length === 0) integer = '0'
    integer = integer.replace(/\B(?=(\d{3})+(?!\d))/g, '.')
    this.inputTarget.value = integer + ',' + cents
    this.updateHelper()
  }

  updateHelper() {
    const helper = this.element.querySelector('[data-currency-helper]')
    if (helper) {
      // Extract numeric value from formatted input
      const raw = this.inputTarget.value.replace(/\./g, '').replace(',', '.')
      // Ensure always two decimal places
      const value = Number.isNaN(Number(raw)) ? 0 : parseFloat(raw)
      helper.textContent = value > 0 ? `Value: ${(value).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL', minimumFractionDigits: 2 })}` : "Enter the value"
    }
  }

  get numericValue() {
    // Extract numeric value from formatted input
    if (!this.inputTarget) return 0
    const raw = this.inputTarget.value.replace(/\./g, '').replace(',', '.')
    return parseFloat(raw) || 0
  }
}
