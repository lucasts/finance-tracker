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
    # OPTIMIZED: Single query instead of N+1
    # In double-entry bookkeeping, only sum asset accounts (user's actual accounts)
    # External accounts (revenue/expense) are used for double-entry but don't represent user's wealth
    
    # Get all asset account IDs
    asset_account_ids = accounts.joins(:account_type)
                              .where(account_types: { role: 'asset' })
                              .pluck(:id)
    
    return DEFAULT_ZERO_BALANCE if asset_account_ids.empty?
    
    # Calculate balance with 2 queries instead of N+1
    credits = Transaction.where(to_account_id: asset_account_ids, status: 'confirmed')
                        .sum(:amount) || DEFAULT_ZERO_BALANCE
    debits = Transaction.where(from_account_id: asset_account_ids, status: 'confirmed')
                       .sum(:amount) || DEFAULT_ZERO_BALANCE
    
    credits - debits
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
    DefaultCategoriesService.create_for_user(self)
  end
end
