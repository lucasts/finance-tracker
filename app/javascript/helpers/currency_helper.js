// Currency Helper - Centralized JavaScript money formatting
// ✅ REFACTOR: Eliminate 4+ different implementations across views

window.CurrencyHelper = {
  // Format amount to Brazilian currency
  format: function(amount, options = {}) {
    const defaults = {
      style: 'currency',
      currency: 'BRL',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    };
    
    const opts = Object.assign(defaults, options);
    
    try {
      return new Intl.NumberFormat('pt-BR', opts).format(amount);
    } catch (e) {
      // Fallback for older browsers
      return `R$ ${amount.toFixed(2).replace('.', ',')}`;
    }
  },
  
  // Normalize input value (from user input to number)
  normalize: function(value) {
    if (typeof value === 'number') return value;
    if (!value || value === '') return 0;
    
    // Remove thousand separators (dots) and convert comma to decimal point
    const normalized = value.toString()
      .replace(/\.(?=\d{3}(\D|$))/g, '')  // Remove dots used as thousand separators
      .replace(',', '.');                 // Convert comma to decimal point
    
    const parsed = parseFloat(normalized);
    return isNaN(parsed) ? 0 : parsed;
  },
  
  // Format for display in forms (with thousands separators)
  formatForDisplay: function(amount) {
    if (!amount || amount === 0) return '';
    
    const formatted = amount.toLocaleString('pt-BR', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    });
    
    return formatted;
  },
  
  // Apply currency mask to input field
  applyMask: function(inputElement) {
    if (!inputElement) return;
    
    inputElement.addEventListener('input', function(e) {
      let value = e.target.value;
      
      // Remove all non-digits
      value = value.replace(/\D/g, '');
      
      // Convert to cents and then to currency format
      const numericValue = parseInt(value) / 100;
      
      if (numericValue === 0 || isNaN(numericValue)) {
        e.target.value = '';
        return;
      }
      
      e.target.value = CurrencyHelper.formatForDisplay(numericValue);
    });
  }
};

// Auto-apply to elements with data-currency attribute
document.addEventListener('DOMContentLoaded', function() {
  const currencyInputs = document.querySelectorAll('[data-currency]');
  currencyInputs.forEach(function(input) {
    CurrencyHelper.applyMask(input);
  });
});

// Export for ES6 modules if needed
if (typeof module !== 'undefined' && module.exports) {
  module.exports = CurrencyHelper;
}
