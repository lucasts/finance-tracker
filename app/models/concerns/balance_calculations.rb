# frozen_string_literal: true

# Concern para cálculos de balance que são comuns entre Account e outros models
module BalanceCalculations
  extend ActiveSupport::Concern
  
  # This concern is now deprecated as balance is cached in the 'balance' column.
  # The methods are kept for reference but should not be used.

  # Calculate balance based on transactions to/from this account
  def calculate_balance_from_transactions
    # DEPRECATED
    0.0
  end
  
  # Cache-friendly balance calculation (if cached_balance column exists)
  def balance_with_cache
    if respond_to?(:cached_balance) && cached_balance.present?
      cached_balance
    else
      calculate_balance_from_transactions
    end
  end
  
  # Update cached balance if the column exists
  def update_cached_balance!
    return unless respond_to?(:cached_balance)
    
    new_balance = calculate_balance_from_transactions
    update_column(:cached_balance, new_balance) if cached_balance != new_balance
    new_balance
  end
  
  # Income total for this account
  def total_income_amount
    return 0.0 unless respond_to?(:income_transactions)
    income_transactions.sum(:amount) || 0.0
  end
  
  # Expense total for this account
  def total_expense_amount
    return 0.0 unless respond_to?(:expense_transactions)  
    expense_transactions.sum(:amount) || 0.0
  end
  
  # Net transfers (in - out)
  def net_transfer_amount
    transfers_in_total = respond_to?(:transfers_in) ? (transfers_in.sum(:amount) || 0.0) : 0.0
    transfers_out_total = respond_to?(:transfers_out) ? (transfers_out.sum(:amount) || 0.0) : 0.0
    transfers_in_total - transfers_out_total
  end
end
