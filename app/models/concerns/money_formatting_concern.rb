# Money formatting concern - focused only on formatting money for display
# Part of the money handling system refactor
module MoneyFormattingConcern
  extend ActiveSupport::Concern

  # Class methods for controllers and services
  class_methods do
    # Format money for display (consolidated from helpers)
    def format_money_display(amount, options = {})
      return 'R$ 0,00' if amount.blank? || amount.zero?

      defaults = {
        currency: 'R$',
        thousands_separator: '.',
        decimal_separator: ',',
        precision: 2,
        show_currency: true
      }
      opts = defaults.merge(options)

      # Convert to BigDecimal for precision
      decimal_amount = amount.is_a?(BigDecimal) ? amount : BigDecimal(amount.to_s)
      
      # Format the number
      formatted = sprintf("%.#{opts[:precision]}f", decimal_amount.abs)
      parts = formatted.split('.')
      
      # Add thousands separators
      integer_part = parts[0].reverse.gsub(/(\d{3})(?=\d)/, "\\1#{opts[:thousands_separator]}").reverse
      decimal_part = parts[1] || '00'
      
      formatted_amount = "#{integer_part}#{opts[:decimal_separator]}#{decimal_part}"
      
      # Add currency and handle negative
      result = opts[:show_currency] ? "#{opts[:currency]} #{formatted_amount}" : formatted_amount
      decimal_amount.negative? ? "-#{result}" : result
    end
  end
end
