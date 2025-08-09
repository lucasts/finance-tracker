require 'digest'

class ImportSession < ApplicationRecord
  belongs_to :user
  belongs_to :account
  has_many :imported_transactions, dependent: :destroy

  validates :source_type, inclusion: { in: %w[ofx csv] }
  validates :account_id, presence: true

  before_validation :compute_file_digest, if: -> { raw_file_changed? && raw_file.present? }
  validates :file_digest, uniqueness: { scope: :account_id, message: 'arquivo já importado para esta conta' }, allow_nil: true

  def compute_file_digest
    self.file_digest = Digest::SHA256.hexdigest(raw_file.to_s)
  end

  def file_size
    raw_file&.bytesize || 0
  end
end
