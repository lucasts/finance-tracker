class Account < ApplicationRecord
  include BalanceCalculations
  include MoneyParsingConcern
  
  # User association
  belongs_to :user
  
  # Existing associations
  belongs_to :account_type
  has_many :import_sessions, dependent: :nullify
  has_many :credit_statements, dependent: :destroy

  has_many :entries, dependent: :destroy
  has_many :transactions, through: :entries, source: :transaction_record

  validates :name, presence: true

  # Helper methods for different transaction types
  def income_transactions
    transactions.income.confirmed
  end

  def expense_transactions
    transactions.expense.confirmed
  end

  def transfers_in
    transactions.transfer.confirmed
  end

  def transfers_out
    transactions.transfer.confirmed
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
