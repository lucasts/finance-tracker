# Unified money handling concern — single source of truth for all money
# parsing, formatting, validation, and attribute normalization.
#
# Module-level API (callable anywhere):
#   MoneyConcern.parse_money_string("1.234,56")  # => BigDecimal("1234.56")
#   MoneyConcern.format_money_display(amount)
#   MoneyConcern.valid_money_format?(value)
#   MoneyConcern.extract_currency_symbol(value)
#
# When included in an ActiveRecord model the same methods are available as
# class methods and a before_validation callback normalises money attributes.
module MoneyConcern
  extend ActiveSupport::Concern

  # -------------------------------------------------------------------------
  # Module-level API — callable as MoneyConcern.method_name from helpers/services
  # -------------------------------------------------------------------------

  # Parses a user-supplied money string (BRL, US, plain numeric) to BigDecimal.
  # Handles: "1.234,56", "1,234.56", "R$ 1.234,56", "-99.99", 42, nil, etc.
  def self.parse_money_string(value)
    return BigDecimal("0") if value.blank?
    return BigDecimal(value.to_s) if value.is_a?(Numeric)
    return BigDecimal("0") unless value.is_a?(String)

    normalized = value.gsub(/[^\d.,\-]/, "").strip
    return BigDecimal("0") if normalized.empty?

    is_negative = normalized.start_with?("-")
    normalized = normalized.delete("-")

    if normalized.match?(/^\d{1,3}(\.\d{3})*,\d{2}$/)
      # European/BRL thousands + comma decimal: 1.234,56
      normalized = normalized.delete(".").gsub(",", ".")
    elsif normalized.match?(/^\d{1,3}(,\d{3})*\.\d{2}$/)
      # US thousands + dot decimal: 1,234.56
      normalized = normalized.delete(",")
    elsif normalized.count(",") == 1 && normalized.count(".") == 0
      # Plain comma decimal: 1234,56
      normalized = normalized.gsub(",", ".")
    elsif normalized.count(".") == 1 && normalized.count(",") == 0
      # Plain dot decimal: 1234.56 — already correct
    elsif normalized.match?(/^\d+$/)
      # Integer-only: 1234 — already correct
    else
      # Fallback: treat rightmost separator as decimal
      last_sep = [ normalized.rindex(","), normalized.rindex(".") ].compact.max
      if last_sep
        before_decimal = normalized[0...last_sep].delete(".,")
        after_decimal  = normalized[last_sep + 1..]
        normalized = "#{before_decimal}.#{after_decimal}"
      end
    end

    result = BigDecimal(normalized)
    is_negative ? -result : result
  rescue ArgumentError, TypeError
    BigDecimal("0")
  end

  # Formats a BigDecimal/Numeric amount using Brazilian currency conventions.
  # Options: currency ("R$"), thousands_separator ("."), decimal_separator (","),
  #          precision (2), show_currency (true).
  def self.format_money_display(amount, options = {})
    return "R$ 0,00" if amount.blank? || amount.zero?

    defaults = {
      currency: "R$",
      thousands_separator: ".",
      decimal_separator: ",",
      precision: 2,
      show_currency: true
    }
    opts = defaults.merge(options)

    decimal_amount = amount.is_a?(BigDecimal) ? amount : BigDecimal(amount.to_s)

    formatted = sprintf("%.#{opts[:precision]}f", decimal_amount.abs)
    integer_str, decimal_str = formatted.split(".")

    integer_with_sep = integer_str.reverse
                                  .gsub(/(\d{3})(?=\d)/, "\\1#{opts[:thousands_separator]}")
                                  .reverse

    formatted_amount = "#{integer_with_sep}#{opts[:decimal_separator]}#{decimal_str}"
    result = opts[:show_currency] ? "#{opts[:currency]} #{formatted_amount}" : formatted_amount
    decimal_amount.negative? ? "-#{result}" : result
  end

  # Returns true when value is blank (not supplied) or a syntactically valid
  # money string/number. Returns false only for garbage strings.
  def self.valid_money_format?(value)
    return true if value.blank? || value.is_a?(Numeric)
    return false unless value.is_a?(String)

    value.match?(/^-?\s*[R$\$€£¥]?\s*[\d.,]+\s*$/)
  end

  # Returns the currency symbol found in the string, or nil.
  def self.extract_currency_symbol(value)
    return nil unless value.is_a?(String)

    match = value.match(/([R$\$€£¥]+)/)
    match ? match[1] : nil
  end

  # -------------------------------------------------------------------------
  # Class methods on including models — delegate to module-level
  # -------------------------------------------------------------------------

  class_methods do
    def parse_money_string(value)
      MoneyConcern.parse_money_string(value)
    end

    def format_money_display(amount, options = {})
      MoneyConcern.format_money_display(amount, options)
    end

    def valid_money_format?(value)
      MoneyConcern.valid_money_format?(value)
    end

    def extract_currency_symbol(value)
      MoneyConcern.extract_currency_symbol(value)
    end
  end

  # -------------------------------------------------------------------------
  # Instance-level normalization — runs before_validation on including models
  # -------------------------------------------------------------------------

  included do
    before_validation :normalize_money_attributes, if: :has_money_attributes?
  end

  def normalize_money_attributes
    self.class.column_names.each do |column|
      next unless money_column?(column)

      value = send(column)
      next if value.nil?

      send("#{column}=", self.class.parse_money_string(value))
    end
  end

  private

  def money_column?(column_name)
    money_patterns = %w[amount price cost value total balance salary]
    money_patterns.any? { |pattern| column_name.include?(pattern) } ||
      (respond_to?(:column_for_attribute) &&
       %i[decimal float].include?(column_for_attribute(column_name)&.type))
  end

  def has_money_attributes?
    self.class.column_names.any? { |col| money_column?(col) }
  end
end
