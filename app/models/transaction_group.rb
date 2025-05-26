class TransactionGroup < ApplicationRecord
  has_many :transactions, dependent: :nullify

  validates :name, presence: true
  validates :group_type, presence: true, inclusion: { in: %w[installment loan transfer] }
end
