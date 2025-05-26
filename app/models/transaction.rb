class Transaction < ApplicationRecord
  belongs_to :from_account, class_name: "Account"
  belongs_to :to_account, class_name: "Account", optional: true
  belongs_to :category
  belongs_to :transaction_group, optional: true

  validates :description, :amount, :date, :period, :transaction_type, presence: true
  validates :transaction_type, inclusion: { in: %w[income expense] }

  scope :for_period, ->(period) { where(period: period) }
end
