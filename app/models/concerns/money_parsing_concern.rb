# Money parsing concern - focused only on parsing money strings to BigDecimal
# Part of the money handling system refactor
module MoneyParsingConcern
  extend ActiveSupport::Concern

  # Class methods for controllers and services
  class_methods do
    # Parse money string to BigDecimal (consolidated from multiple places)
    def parse_money_string(value)
      return BigDecimal("0") if value.blank?
      return BigDecimal(value.to_s) if value.is_a?(Numeric)

      return BigDecimal("0") unless value.is_a?(String)

      # Remove common formatting and normalize
      # Handles: "1.234,56", "1,234.56", "R$ 1.234,56", "$1,234.56", etc.
      normalized = value.to_s
                       .gsub(/[^\d.,\-]/, "") # Remove currency symbols, spaces
                       .strip

      return BigDecimal("0") if normalized.empty?

      # Handle negative values
      is_negative = normalized.start_with?("-")
      normalized = normalized.gsub("-", "")

      # Determine decimal separator based on format patterns
      if normalized.match?(/^\d{1,3}(\.\d{3})*,\d{2}$/)
        # European format: 1.234.567,89 or 1.234,56
        normalized = normalized.gsub(".", "").gsub(",", ".")
      elsif normalized.match?(/^\d{1,3}(,\d{3})*\.\d{2}$/)
        # US format: 1,234,567.89 or 1,234.56
        normalized = normalized.gsub(",", "")
      elsif normalized.count(",") == 1 && normalized.count(".") == 0
        # Simple comma as decimal: 1234,56
        normalized = normalized.gsub(",", ".")
      elsif normalized.count(".") == 1 && normalized.count(",") == 0
        # Simple dot as decimal: 1234.56
        # Already correct format
      elsif normalized.match?(/^\d+$/)
        # Integer only: 1234
        # Already correct format
      else
        # Fallback: assume last separator is decimal
        last_separator_index = [ normalized.rindex(","), normalized.rindex(".") ].compact.max
        if last_separator_index
          before_decimal = normalized[0...last_separator_index].gsub(/[,.]/, "")
          after_decimal = normalized[last_separator_index + 1..-1]
          normalized = "#{before_decimal}.#{after_decimal}"
        end
      end

      result = BigDecimal(normalized)
      is_negative ? -result : result
    rescue ArgumentError, TypeError
      BigDecimal("0")
    end
  end
end
