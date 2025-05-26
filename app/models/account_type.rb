class AccountType < ApplicationRecord
  has_many :accounts, dependent: :restrict_with_error

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :role, presence: true, inclusion: { in: %w[asset income expense] }
end
