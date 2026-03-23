class User < ApplicationRecord
  include FinancialConstants
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Associations
  has_many :transactions, dependent: :destroy
  has_many :accounts, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :recurring_commitments, dependent: :destroy
  has_many :installment_plans, dependent: :destroy
  has_many :import_sessions, dependent: :nullify
  has_many :reconciliation_entries, dependent: :nullify

  validates :email, presence: true, uniqueness: true

  # Callbacks
  after_create :create_default_categories

  # Business methods for financial calculations
  def total_balance
    # Sum balances from all asset accounts (user's actual accounts)
    accounts.joins(:account_type)
            .where(account_types: { role: "asset" })
            .sum(&:balance)
  end

  def monthly_income(date = Date.current)
    transactions.income
               .in_competence_month(date)
               .confirmed
               .sum(:amount)
  end

  def monthly_expenses(date = Date.current)
    transactions.expense
               .in_competence_month(date)
               .confirmed
               .sum(:amount)
  end

  def monthly_balance(date = Date.current)
    monthly_income(date) - monthly_expenses(date)
  end

  def pending_transactions_count
    transactions.pending.count
  end

  def upcoming_payments(limit = 10)
    transactions.upcoming_payments(limit)
  end

  private

  def create_default_categories
    DefaultCategoriesService.call(user: self)
  end
end
