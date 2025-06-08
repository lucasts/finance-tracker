class Account < ApplicationRecord
  # Associação de usuário
  belongs_to :user
  
  # Associações existentes
  belongs_to :account_type
  has_many :transactions_from, class_name: "Transaction", foreign_key: :from_account_id, dependent: :restrict_with_error
  has_many :transactions_to, class_name: "Transaction", foreign_key: :to_account_id, dependent: :restrict_with_error
  has_many :import_sessions, dependent: :nullify

  validates :name, presence: true

  # Calcula o saldo da conta baseado nas transações
  def balance
    # Entradas: receita + destino de transferência
    credits = transactions_to.confirmed.sum(:amount) || 0.0
    # Saídas: despesa + origem de transferência
    debits = transactions_from.confirmed.sum(:amount) || 0.0
    credits - debits
  end

  # Métodos auxiliares para diferentes tipos de transação
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

  def total_income
    income_transactions.sum(:amount) || 0.0
  end

  def total_expenses
    expense_transactions.sum(:amount) || 0.0
  end

  def net_transfers
    (transfers_in.sum(:amount) || 0.0) - (transfers_out.sum(:amount) || 0.0)
  end
end
