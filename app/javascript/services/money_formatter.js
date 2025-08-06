// MoneyFormatter - Unified money formatting service
// Replaces multiple inconsistent implementations across the app

export class MoneyFormatter {
  static DEFAULTS = {
    locale: 'pt-BR',
    currency: 'BRL',
    style: 'currency'
  }

  // Format amount for display (consistent with Rails helper)
  static format(amount, options = {}) {
    if (amount === null || amount === undefined || amount === '') {
      return 'R$ 0,00'
    }

    const value = typeof amount === 'string' ? this.parse(amount) : Number(amount)
    
    if (isNaN(value)) {
      return 'R$ 0,00'
    }

    const config = { ...this.DEFAULTS, ...options }
    
    try {
      return new Intl.NumberFormat(config.locale, {
        style: config.style,
        currency: config.currency,
        minimumFractionDigits: 2,
        maximumFractionDigits: 2
      }).format(value)
    } catch (error) {
      // Fallback for older browsers
      return `R$ ${value.toFixed(2).replace('.', ',').replace(/\B(?=(\d{3})+(?!\d))/g, '.')}`
    }
  }

  // Parse user input to number (from Brazilian format)
  static parse(input) {
    if (typeof input === 'number') return input
    if (!input || input === '') return 0

    // Remove currency symbols and normalize
    const normalized = input.toString()
      .replace(/[R$\s]/g, '')                    // Remove R$ and spaces
      .replace(/\.(?=\d{3}(\D|$))/g, '')        // Remove thousand separators (dots)
      .replace(',', '.')                        // Convert comma to decimal point

    const parsed = parseFloat(normalized)
    return isNaN(parsed) ? 0 : parsed
  }

  // Apply currency mask to input element
  static mask(element) {
    if (!element) return

    element.addEventListener('input', function(event) {
      let value = event.target.value

      // Remove all non-digits
      value = value.replace(/\D/g, '')

      if (value === '' || value === '0') {
        event.target.value = ''
        return
      }

      // Convert cents to currency format
      const numericValue = parseInt(value) / 100

      // Format using the same logic as display
      const formatted = MoneyFormatter.formatForInput(numericValue)
      event.target.value = formatted
    })
  }

  // Format for input fields (without currency symbol)
  static formatForInput(amount) {
    if (!amount || amount === 0) return ''

    return amount.toLocaleString('pt-BR', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    })
  }

  // Get numeric value from formatted input
  static getNumericValue(element) {
    if (!element || !element.value) return 0
    return this.parse(element.value)
  }
}

// Auto-initialize currency inputs on page load
document.addEventListener('DOMContentLoaded', function() {
  const currencyInputs = document.querySelectorAll('[data-money-input]')
  currencyInputs.forEach(input => MoneyFormatter.mask(input))
})
