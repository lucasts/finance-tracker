# frozen_string_literal: true

# Concern para cálculos de balance que são comuns entre Account e outros models
module BalanceCalculations
  extend ActiveSupport::Concern
  
  # Calculate balance based on transactions to/from this account
  def calculate_balance_from_transactions
    # Inflows: income + transfer destination (transactions TO this account)
    credits = if respond_to?(:transactions_to)
                transactions_to.confirmed.sum(:amount) || 0.0
              else
                0.0
              end
    
    # Outflows: expense + transfer source (transactions FROM this account)
    debits = if respond_to?(:transactions_from)
               transactions_from.confirmed.sum(:amount) || 0.0
             else
               0.0
             end
    
    credits - debits
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
