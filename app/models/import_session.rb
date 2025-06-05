class ImportSession < ApplicationRecord
  belongs_to :user
  belongs_to :account
  has_many :imported_transactions, dependent: :destroy

  validates :source_type, inclusion: { in: %w[ofx csv] }
  validates :account_id, presence: true

  def file_size
    raw_file&.bytesize || 0
  end
end
