# frozen_string_literal: true

# Service to suggest heuristic matches for ImportedTransaction
class ImportMatchingService
  def self.call(imported_transaction:)
    new(imported_transaction).suggest_matches
  end

  def initialize(imported_transaction)
    @imported_transaction = imported_transaction
  end

  def suggest_matches
    cfg = Rails.application.config.dedup
    amount_pct_tolerance = (cfg[:matching_amount_percentage] || FinancialConstants::AMOUNT_PERCENTAGE_TOLERANCE).to_f
    date_tol_days        = (cfg[:similar_date_tolerance_days] || FinancialConstants::DATE_TOLERANCE_DAYS).to_i

    imported_amount = FinancialConstants.safe_to_decimal(@imported_transaction.amount).abs
    amount_tolerance = [ FinancialConstants::AMOUNT_ABSOLUTE_TOLERANCE, imported_amount * amount_pct_tolerance ].max
    imported_date = FinancialConstants.safe_to_date(@imported_transaction.event_date)

    candidates = Transaction.where(user_id: @imported_transaction.import_session.user_id)
      .where("ABS(amount - ?) <= ?", imported_amount, amount_tolerance)
      .where("event_date BETWEEN ? AND ?",
        (imported_date - date_tol_days),
        (imported_date + date_tol_days))

    desc = @imported_transaction.description.to_s.downcase
    desc_norm = desc.gsub(/[^a-z0-9]/, "")
    candidates = candidates.select do |tx|
      tx_desc = tx.description.to_s.downcase.gsub(/[^a-z0-9]/, "")
      # Similarity: at least 6 characters in common, or similarity >= 0.6
      (tx_desc[0, 8] == desc_norm[0, 8]) ||
      (tx_desc.include?(desc_norm[0, 6])) ||
      (desc_norm.include?(tx_desc[0, 6])) ||
      (string_similarity(tx_desc, desc_norm) >= 0.6)
    end

    # Installment: regex for "05/12", "parcela 3 de 10", etc
    installment_match = nil
    if @imported_transaction.installment_info.present? || desc =~ /(\d{1,2}\/\d{1,2})|(parcela\s*\d+\s*(de|\/|-)*\d+)/i
      base = desc.gsub(/(\d{1,2}\/\d{1,2})|(parcela\s*\d+\s*(de|\/|-)*\d+)/i, "").strip
      installment_match = InstallmentPlan.where(user_id: @imported_transaction.import_session.user_id)
        .where("LOWER(name) LIKE ?", "%#{base[0, 8].downcase}%")
        .first
    end

    # Recurring: similarity + approximate value
    imported_amount = FinancialConstants.safe_to_decimal(@imported_transaction.amount)
    recurring_tol = (cfg[:recurring_amount_tolerance] || FinancialConstants::RECURRING_AMOUNT_TOLERANCE).to_f
    recurring_match = RecurringCommitment.where(user_id: @imported_transaction.import_session.user_id)
      .where("LOWER(name) LIKE ?", "%#{desc[0, 8].downcase}%")
      .select do |rc|
        expected_amount = FinancialConstants.safe_to_decimal(rc.expected_amount)
        tolerance = [ FinancialConstants::AMOUNT_ABSOLUTE_TOLERANCE, expected_amount * recurring_tol ].max
        (expected_amount - imported_amount).abs <= tolerance
      end
      .first

    {
      candidates: candidates,
      installment_plan: installment_match,
      recurring_commitment: recurring_match
    }
  end

  private

  # String similarity (simple Jaccard)
  def string_similarity(a, b)
    return 0 if a.blank? || b.blank?
    a_set = a.chars.to_set
    b_set = b.chars.to_set
    inter = a_set & b_set
    union = a_set | b_set
    FinancialConstants.safe_to_float(inter.size) / union.size
  end
end
