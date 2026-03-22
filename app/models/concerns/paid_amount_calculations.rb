# frozen_string_literal: true

# Concern para eliminar duplicação de lógica de amounts pagos
module PaidAmountCalculations
  extend ActiveSupport::Concern
  include FinancialConstants

  included do
    # Assumes the including model has_many :transactions
  end

  # Total amount paid (confirmed transactions)
  def amount_paid
    confirmed_transactions.sum(:amount) || 0.0
  end

  # Pending amount (if total_amount exists)
  def amount_pending
    return 0 unless respond_to?(:total_amount) && total_amount.present?
    [ total_amount - amount_paid, 0 ].max
  end

  # Percentage paid (if total_amount exists)
  def percentage_paid
    return FinancialConstants::DEFAULT_PERCENTAGE unless respond_to?(:total_amount) && total_amount.present? && total_amount > 0
    FinancialConstants.calculate_percentage(amount_paid, total_amount)
  end

  # Number of paid transactions/installments
  def paid_count
    confirmed_transactions.count
  end

  # Helper method for confirmed transactions
  def confirmed_transactions
    transactions.where(status: "confirmed")
  end

  # Average amount of confirmed transactions
  def average_paid_amount
    return 0 if paid_count == 0
    (amount_paid / paid_count).round(2)
  end
end
