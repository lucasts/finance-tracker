class ImportedTransaction < ApplicationRecord
  include AmountNormalization
  include FinancialConstants
  
  belongs_to :import_session
  belongs_to :installment_plan, optional: true
  belongs_to :recurring_commitment, optional: true
  belongs_to :matched_transaction, class_name: 'Transaction', optional: true
  belongs_to :potential_transfer_with, class_name: 'ImportedTransaction', optional: true
  has_one :reconciliation_entry, dependent: :destroy

  validates :raw_data, presence: true

  before_validation :ensure_fingerprint
  after_save :update_status_from_reconciliation

  scope :possible_duplicates, -> { where(possible_duplicate: true) }
  scope :transfer_candidates, -> { where(transfer_candidate: true) }

  FINGERPRINT_VERSION = 1

  def self.generate_fingerprint(description:, amount:, event_date:, payment_date: nil)
    require 'digest'
    
    date = event_date || payment_date
    date_str = date&.strftime('%Y-%m-%d') || ''
    amount_cents = amount.present? ? (BigDecimal(amount.to_s) * 100).to_i : 0
    norm_desc = normalize_description(description)
    
    base_string = "#{date_str}|#{amount_cents}|#{norm_desc}"
    Digest::SHA256.hexdigest(base_string)[0, 48]
  end

  def self.normalize_description(desc)
    return '' if desc.nil?
    # Remove punctuation and normalize spacing/accents
    normalized = I18n.transliterate(desc.to_s.downcase.strip)
    normalized.gsub(/[^\w\s]/, '').gsub(/\s+/, ' ').strip
  end

  def update_status_from_reconciliation
    if reconciliation_entry&.action == 'create_new' && reconciliation_entry&.linked_transaction_id
      update_column(:status, 'conciliated')
    elsif reconciliation_entry&.action == 'associate'
      update_column(:status, 'associated')
    elsif reconciliation_entry&.action == 'ignore'
      update_column(:status, 'ignored')
    end
  end

  private

  def ensure_fingerprint
    return if fingerprint.present?
    
    self.fingerprint_version ||= FINGERPRINT_VERSION
    self.fingerprint = self.class.generate_fingerprint(
      description: description,
      amount: amount,
      event_date: event_date,
      payment_date: payment_date
    )
  end
end
