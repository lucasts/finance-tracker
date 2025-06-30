// Shared utility functions for formatting
export const FormattingUtils = {
  formatCurrency(value) {
    return new Intl.NumberFormat('pt-BR', {
      style: 'currency',
      currency: 'BRL'
    }).format(value)
  },

  formatDate(date, options = {}) {
    const defaultOptions = {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric'
    }
    
    return new Intl.DateTimeFormat('pt-BR', { ...defaultOptions, ...options }).format(date)
  },

  formatDateForBackend(date) {
    // Format date avoiding timezone issues
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    return `${year}-${month}-${day}`
  }
}
