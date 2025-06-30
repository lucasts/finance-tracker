class Account < ApplicationRecord
  include BalanceCalculations
  include MoneyParsingConcern
  
  # User association
  belongs_to :user
  
  # Existing associations
  belongs_to :account_type
  has_many :transactions_from, class_name: "Transaction", foreign_key: :from_account_id, dependent: :restrict_with_error
  has_many :transactions_to, class_name: "Transaction", foreign_key: :to_account_id, dependent: :restrict_with_error
  has_many :import_sessions, dependent: :nullify
  has_many :credit_statements, dependent: :destroy

  validates :name, presence: true

  alias_method :balance, :calculate_balance_from_transactions

  # Helper methods for different transaction types
  def income_transactions
    transactions_to.income.confirmed
  end

  def expense_transactions
    transactions_from.expense.confirmed
  end

  def transfers_in
    transactions_to.transfer.confirmed
  end

  def transfers_out
    transactions_from.transfer.confirmed
  end

  alias_method :total_income, :total_income_amount
  alias_method :total_expenses, :total_expense_amount  
  alias_method :net_transfers, :net_transfer_amount

  # Credit card specific methods
  def credit_card?
    account_type&.code == "CREDIT_CARD"
  end

  def ensure_credit_statement_for_period(period)
    return nil unless credit_card?
    
    CreditStatementService.find_or_create_statement(self, period)
  end

  def create_future_statements(months_ahead = 12)
    return [] unless credit_card?
    
    CreditStatementService.create_future_statements(self, months_ahead)
  end
end
