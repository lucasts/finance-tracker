# Helper module for money formatting in views and controllers
module MoneyFormattingHelper
  # Parse money string to BigDecimal (consolidated from multiple places)
  def self.parse_money_string(value)
    return BigDecimal('0') if value.blank?
    return BigDecimal(value.to_s) if value.is_a?(Numeric)
    
    return BigDecimal('0') unless value.is_a?(String)

    # Remove common formatting and normalize
    # Handles: "1.234,56", "1,234.56", "R$ 1.234,56", "$1,234.56", etc.
    normalized = value.to_s
                     .gsub(/[^\d.,\-]/, '') # Remove currency symbols, spaces
                     .strip

    return BigDecimal('0') if normalized.empty?

    # Handle negative values
    is_negative = normalized.start_with?('-')
    normalized = normalized.gsub('-', '')

    # Determine decimal separator based on format patterns
    if normalized.match?(/^\d{1,3}(\.\d{3})*,\d{2}$/)
      # European format: 1.234.567,89 or 1.234,56
      normalized = normalized.gsub('.', '').gsub(',', '.')
    elsif normalized.match?(/^\d{1,3}(,\d{3})*\.\d{2}$/)
      # US format: 1,234,567.89 or 1,234.56
      normalized = normalized.gsub(',', '')
    elsif normalized.count(',') == 1 && normalized.count('.') == 0
      # Simple comma as decimal: 1234,56
      normalized = normalized.gsub(',', '.')
    elsif normalized.count('.') == 1 && normalized.count(',') == 0
      # Simple dot as decimal: 1234.56
      # Already correct format
    elsif normalized.match?(/^\d+$/)
      # Integer only: 1234
      # Already correct format
    else
      # Fallback: assume last separator is decimal
      last_separator_index = [normalized.rindex(','), normalized.rindex('.')].compact.max
      if last_separator_index
        before_decimal = normalized[0...last_separator_index].gsub(/[,.]/, '')
        after_decimal = normalized[last_separator_index + 1..-1]
        normalized = "#{before_decimal}.#{after_decimal}"
      end
    end

    result = BigDecimal(normalized)
    is_negative ? -result : result
  rescue ArgumentError, TypeError
    BigDecimal('0')
  end

  # Format money for display (consolidated from helpers)
  def self.format_money_display(amount, options = {})
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

  # Validate money format
  def self.valid_money_format?(value)
    return true if value.blank? || value.is_a?(Numeric)
    return false unless value.is_a?(String)

    # Allow various formats
    value.match?(/^-?\s*[R$\$€£¥]?\s*[\d.,]+\s*$/)
  end
end
