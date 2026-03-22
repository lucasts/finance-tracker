class Entry < ApplicationRecord
  include BalanceCache

  belongs_to :transaction_record, class_name: "Transaction", foreign_key: "transaction_id"
  belongs_to :account

  enum :entry_type, { debit: "debit", credit: "credit" }

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :entry_type, presence: true
end
