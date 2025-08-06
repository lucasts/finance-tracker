class ImportedTransaction < ApplicationRecord
  include AmountNormalization
  include FinancialConstants
  
  belongs_to :import_session
  belongs_to :installment_plan, optional: true
  belongs_to :recurring_commitment, optional: true
  belongs_to :matched_transaction, class_name: 'Transaction', optional: true
  has_one :reconciliation_entry, dependent: :destroy

  validates :raw_data, presence: true

  after_save :update_status_from_reconciliation

  def update_status_from_reconciliation
    if reconciliation_entry&.action == 'create_new' && reconciliation_entry&.linked_transaction_id
      update_column(:status, 'conciliated')
    elsif reconciliation_entry&.action == 'associate'
      update_column(:status, 'associated')
    elsif reconciliation_entry&.action == 'ignore'
      update_column(:status, 'ignored')
    end
  end
end
