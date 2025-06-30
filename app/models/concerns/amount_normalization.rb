# frozen_string_literal: true

# Concern para normalização de valores monetários
module AmountNormalization
  extend ActiveSupport::Concern
  
  included do
    before_validation :normalize_amount_fields
  end
  
  private
  
  def normalize_amount_fields
    # Find all amount-related fields in the model
    amount_fields = self.class.column_names.select { |col| col.include?('amount') || col == 'amount' }
    
    amount_fields.each do |field|
      value = self.send(field)
      next if value.nil?
      
      if value.is_a?(String) && value.present?
        # Remove thousand separators (dots) and convert comma to decimal point
        normalized = value.gsub(/\.(?=\d{3}(\D|$))/, '').gsub(',', '.')
        self.send("#{field}=", BigDecimal(normalized))
      elsif value.is_a?(String)
        self.send("#{field}=", BigDecimal('0'))
      end
    rescue ArgumentError
      # If conversion fails, set to 0
      self.send("#{field}=", BigDecimal('0'))
    end
  end
  
  class_methods do
    # Class method to normalize amount parameters in controllers
    def normalize_amount_param(param_value)
      return param_value if param_value.is_a?(Numeric)
      return 0 if param_value.blank?
      
      # Remove thousand separators (dots) and convert comma to decimal point
      normalized = param_value.to_s.gsub(/\.(?=\d{3}(\D|$))/, '').gsub(',', '.')
      BigDecimal(normalized)
    rescue ArgumentError
      BigDecimal('0')
    end
  end
end
