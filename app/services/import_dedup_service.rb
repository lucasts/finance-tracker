# frozen_string_literal: true

class ImportDedupService
  # Performs advanced duplicate filtering and creation of ImportedTransaction records.
  # Contract:
  #  - import_session: ImportSession (persisted) to attach created ImportedTransaction records
  #  - parsed_transactions: Array of Hashes with keys (description, amount, event_date, payment_date, transaction_type, etc.)
  # Returns: Array<ImportedTransaction> created (excluding skipped duplicates)
  # Heuristics:
  # 1. Exact dedup: same normalized description AND same date AND amount difference <= absolute tolerance
  # 2. Tolerance dedup: same normalized description AND date diff <= 1 day AND amount diff <= absolute tolerance
  # 3. Similar flag (possible_duplicate): same normalized description AND date diff <= DATE_TOLERANCE_DAYS AND amount diff <= 2.00
  # 4. Approximate description match: allow 1 edit (insertion / substitution) after normalization to cope with accent loss / minor glitches
  def self.call(import_session:, parsed_transactions: [])
    new(import_session, parsed_transactions).process
  end

  def initialize(import_session, parsed_transactions)
    @import_session = import_session
    @transactions = parsed_transactions || []
    cfg = Rails.application.config.dedup
    @amount_tolerance        = BigDecimal(cfg[:exact_amount_tolerance]&.to_s  || FinancialConstants::AMOUNT_ABSOLUTE_TOLERANCE.to_s)
    @date_tolerance_days     = (cfg[:exact_date_tolerance_days]               || FinancialConstants::EXACT_DATE_TOLERANCE_DAYS).to_i
    @similar_amount_tol      = BigDecimal(cfg[:similar_amount_tolerance]&.to_s || FinancialConstants::SIMILAR_AMOUNT_TOLERANCE.to_s)
    @similar_date_tol_days   = (cfg[:similar_date_tolerance_days]             || FinancialConstants::DATE_TOLERANCE_DAYS).to_i
  end

  def process
    preload_existing
    created = []
    @transactions.each do |tx|
      nd = ImportedTransaction.normalize_description(tx[:description])
      tx_date = FinancialConstants.safe_to_date(tx[:event_date])
      tx_amount = FinancialConstants.safe_to_decimal(tx[:amount])

      unless nd.present? && tx_date && tx_amount
        created << create_and_index(tx, nd)
        next
      end

      bucket = candidate_bucket(nd)

      # Exact duplicate
      if exact_duplicate?(bucket, tx_date, tx_amount)
        next
      end

      # Tolerance duplicate
      if tolerance_duplicate?(bucket, tx_date, tx_amount)
        next
      end

      record = create_and_index(tx, nd)
      if similar_to_bucket?(bucket, record) || similar_by_amount_date?(record)
        record.update_column(:possible_duplicate, true)
      end
      created << record
    end
    created
  end

  private

  def preload_existing
    @desc_bucket = Hash.new { |h, k| h[k] = [] }
    ImportedTransaction.joins(:import_session)
      .where(import_sessions: { account_id: @import_session.account_id })
      .select(:id, :amount, :event_date, :description)
      .find_each do |row|
        next unless row.event_date && row.amount && row.description
        nd = ImportedTransaction.normalize_description(row.description)
        @desc_bucket[nd] << row
      end
  end

  def candidate_bucket(nd)
    keys = @desc_bucket.keys.select { |k| one_edit_or_less?(k, nd) }
    keys.flat_map { |k| @desc_bucket[k] }
  end

  def exact_duplicate?(bucket, date, amount)
    bucket.any? do |cand|
      next false unless cand.event_date && cand.amount
      cand.event_date == date && (BigDecimal(cand.amount.to_s) - amount).abs <= @amount_tolerance
    end
  end

  def tolerance_duplicate?(bucket, date, amount)
    bucket.any? do |cand|
      cand.event_date && cand.amount && (cand.event_date - date).abs <= @date_tolerance_days &&
        (BigDecimal(cand.amount.to_s) - amount).abs <= @amount_tolerance
    end
  end

  def similar_to_bucket?(bucket, record)
    bucket.any? do |cand|
      next false unless cand.event_date && cand.amount && record.event_date && record.amount
      (cand.event_date - record.event_date).abs <= @similar_date_tol_days &&
        (BigDecimal(cand.amount.to_s) - BigDecimal(record.amount.to_s)).abs <= @similar_amount_tol
    end
  end

  # Fallback similarity: if no near-description matches produced a similarity flag, still flag
  # when there exists ANY prior transaction (regardless of description) within similarity
  # date window and amount window. This broadens user visibility for potential duplicates
  # when description text changed substantially (e.g., institution formatting shifts).
  # NOTE: record is excluded from the comparison to avoid self-matching after create_and_index.
  def similar_by_amount_date?(record)
    return false unless record.event_date && record.amount
    @desc_bucket.each_value do |arr|
      arr.each do |cand|
        next if cand.id == record.id
        next unless cand.event_date && cand.amount
        if (cand.event_date - record.event_date).abs <= @similar_date_tol_days &&
           (BigDecimal(cand.amount.to_s) - BigDecimal(record.amount.to_s)).abs <= @similar_amount_tol
          return true
        end
      end
    end
    false
  end

  def create_and_index(tx, nd)
    record = @import_session.imported_transactions.create!(tx)
    if record.event_date && record.amount
      @desc_bucket[nd] << record
    end
    record
  end

  # One-edit-or-less distance (optimized for small strings)
  def one_edit_or_less?(a, b)
    return true if a == b
    return false if (a.length - b.length).abs > 1
    if a.length > b.length
      a, b = b, a
    end
    i = j = edits = 0
    while i < a.length && j < b.length
      if a[i] == b[j]
        i += 1; j += 1
      else
        edits += 1
        return false if edits > 1
        if a.length == b.length
          i += 1; j += 1
        else
          j += 1 # skip char in longer string
        end
      end
    end
    edits += 1 if j < b.length || i < a.length
    edits <= 1
  end
end
