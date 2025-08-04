class Account < ApplicationRecord
  include MoneyParsingConcern
  
  # User association
  belongs_to :user
  
  # Existing associations
  belongs_to :account_type
  has_many :import_sessions, dependent: :nullify
  has_many :credit_statements, dependent: :destroy

  has_many :entries, dependent: :restrict_with_error
  has_many :transactions, through: :entries, source: :transaction_record

  validates :name, presence: true

  # Balance calculation based on double-entry bookkeeping
  def balance
    return 0.0 if account_type.nil?
    
    # In double-entry bookkeeping:
    # - Debit entries increase asset accounts and decrease liability accounts
    # - Credit entries decrease asset accounts and increase liability accounts
    # - For asset accounts: balance = debits - credits
    # - For liability accounts: balance = credits - debits
    
    debit_total = entries.joins(:transaction_record).where(
      transactions: { status: 'confirmed' }, 
      entry_type: 'debit'
    ).sum(:amount) || 0.0
    
    credit_total = entries.joins(:transaction_record).where(
      transactions: { status: 'confirmed' }, 
      entry_type: 'credit'
    ).sum(:amount) || 0.0
    
    if account_type.asset_type?
      debit_total - credit_total
    else
      credit_total - debit_total
    end
  end

  # Helper methods for different transaction types
  def income_transactions
    transactions.where(transaction_type: 'income').joins(:entries).where(entries: { account_id: id, entry_type: 'debit' })
  end

  def expense_transactions
    transactions.where(transaction_type: 'expense').joins(:entries).where(entries: { account_id: id, entry_type: 'credit' })
  end

  def transfers_in
    Transaction.where(id: entries.joins(:transaction_record).where(
      transactions: { transaction_type: 'transfer' }, 
      entry_type: 'debit'
    ).select(:transaction_id))
  end

  def transfers_out
    Transaction.where(id: entries.joins(:transaction_record).where(
      transactions: { transaction_type: 'transfer' }, 
      entry_type: 'credit'
    ).select(:transaction_id))
  end

  # Helper methods for calculating totals
  def total_income_amount
    entries.joins(:transaction_record).where(
      transactions: { transaction_type: 'income' }, 
      entry_type: 'debit'
    ).sum(:amount).to_f
  end

  def total_expense_amount
    entries.joins(:transaction_record).where(
      transactions: { transaction_type: 'expense' }, 
      entry_type: 'credit'
    ).sum(:amount).to_f
  end

  def net_transfer_amount
    transfers_in_amount = entries.joins(:transaction_record).where(
      transactions: { transaction_type: 'transfer' }, 
      entry_type: 'debit'
    ).sum(:amount).to_f
    
    transfers_out_amount = entries.joins(:transaction_record).where(
      transactions: { transaction_type: 'transfer' }, 
      entry_type: 'credit'
    ).sum(:amount).to_f
    
    transfers_in_amount - transfers_out_amount
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
