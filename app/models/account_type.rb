class AccountType < ApplicationRecord
  has_many :accounts, dependent: :restrict_with_error

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :role, presence: true, inclusion: { in: %w[asset liability equity income expense] }

  def asset_type?
    role == "asset"
  end

  def liability_type?
    role == "liability"
  end

  def equity_type?
    role == "equity"
  end

  def income_type?
    role == "income"
  end

  def expense_type?
    role == "expense"
  end
end
