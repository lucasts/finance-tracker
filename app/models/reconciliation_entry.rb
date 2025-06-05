class ReconciliationEntry < ApplicationRecord
  belongs_to :imported_transaction
  belongs_to :linked_transaction, class_name: 'Transaction', foreign_key: :transaction_id, optional: true
  belongs_to :user

  validates :action, inclusion: { in: %w[associate create_new ignore edit] }
  validates :decided_at, presence: true
end
