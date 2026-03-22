# Money normalization concern - focused only on automatic attribute normalization
# Part of the money handling system refactor
module MoneyNormalizationConcern
  extend ActiveSupport::Concern

  # Instance methods for models
  def normalize_money_attributes
    self.class.column_names.each do |column|
      if money_column?(column)
        value = self.send(column)
        next if value.nil?

        normalized = self.class.parse_money_string(value)
        self.send("#{column}=", normalized)
      end
    end
  end

  private

  def money_column?(column_name)
    # Identify money columns by name patterns or database type
    money_patterns = %w[amount price cost value total balance salary]
    money_patterns.any? { |pattern| column_name.to_s.include?(pattern) } ||
      (respond_to?(:column_for_attribute) &&
       [ :decimal, :float ].include?(column_for_attribute(column_name)&.type))
  end

  # Callback to automatically normalize money fields
  included do
    before_validation :normalize_money_attributes, if: :has_money_attributes?
  end

  def has_money_attributes?
    self.class.column_names.any? { |col| money_column?(col) }
  end
end
