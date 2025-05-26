class Account < ApplicationRecord
  belongs_to :account_type
  has_many :transactions_from, class_name: "Transaction", foreign_key: :from_account_id, dependent: :restrict_with_error
  has_many :transactions_to, class_name: "Transaction", foreign_key: :to_account_id, dependent: :restrict_with_error

  validates :name, presence: true
end
