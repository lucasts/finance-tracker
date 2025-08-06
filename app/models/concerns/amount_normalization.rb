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
        # Use MoneyParsingConcern for consistent parsing
        begin
          normalized_value = self.class.parse_money_string(value)
          self.send("#{field}=", normalized_value)
        rescue ArgumentError
          # For invalid strings, leave the original value so validation can catch it
          # Don't set to 0 automatically
        end
      elsif value.is_a?(String)
        # Empty strings are set to nil to allow presence validation to work
        self.send("#{field}=", nil)
      end
    end
  end
  
  class_methods do
    # Class method to normalize amount parameters in controllers
    def normalize_amount_param(param_value)
      return param_value if param_value.nil?
      
      if param_value.is_a?(String) && param_value.present?
        # Use MoneyParsingConcern for consistent parsing
        begin
          parse_money_string(param_value)
        rescue ArgumentError
          # For invalid strings, return original so validation can catch it
          param_value
        end
      elsif param_value.is_a?(String)
        # Empty strings are returned as nil
        nil
      else
        param_value
      end
    end
  end
end
