# Unified money handling concern - includes all money-related functionality
# Organizes money parsing, formatting and validation into focused concerns
module MoneyConcern
  extend ActiveSupport::Concern

  # Include all specialized concerns for instance methods
  include MoneyNormalizationConcern

  # Class methods with all money-related functionality
  class_methods do
    # Parse money string to BigDecimal (consolidated from multiple places)
    def parse_money_string(value)
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

    # Format money for display
    def format_money_display(value, options = {})
      return "R$ 0,00" if value.blank? || value.to_f.zero?
      
      # Convert to BigDecimal for precision
      amount = value.is_a?(BigDecimal) ? value : BigDecimal(value.to_s)
      
      # Format with Brazilian currency pattern
      formatted = "%.2f" % amount.to_f
      formatted = formatted.gsub('.', ',')
      
      # Add thousands separator
      integer_part, decimal_part = formatted.split(',')
      integer_part.gsub!(/(\d)(?=(\d{3})+(?!\d))/, '\1.')
      
      currency_symbol = options[:currency] || "R$"
      "#{currency_symbol} #{integer_part},#{decimal_part}"
    end

    # Validate money format
    def valid_money_format?(value)
      return false if value.blank?
      return true if value.is_a?(Numeric)
      return false unless value.is_a?(String)
      
      # Allow various money formats
      value.to_s.match?(/^\s*[R$€£¥]?\s*[\d.,\-]+\s*$/)
    end

    # Extract currency symbol from string
    def extract_currency_symbol(value)
      return "" if value.blank?
      
      currency_match = value.to_s.match(/^[^\d.,\-]*([R$€£¥]+)/)
      currency_match ? currency_match[1] : ""
    end
  end
end
