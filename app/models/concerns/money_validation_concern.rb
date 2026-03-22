# Money validation concern - focused only on validation and utility methods
# Part of the money handling system refactor
module MoneyValidationConcern
  extend ActiveSupport::Concern

  # Class methods for controllers and services
  class_methods do
    # Validate money format
    def valid_money_format?(value)
      return true if value.blank? || value.is_a?(Numeric)
      return false unless value.is_a?(String)

      # Allow various formats
      value.match?(/^-?\s*[R$\$€£¥]?\s*[\d.,]+\s*$/)
    end

    # Extract currency symbol from string
    def extract_currency_symbol(value)
      return nil unless value.is_a?(String)

      currency_match = value.match(/([R$\$€£¥]+)/)
      currency_match ? currency_match[1] : nil
    end
  end
end
