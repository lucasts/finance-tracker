# Serviço para sugerir matches heurísticos para ImportedTransaction
class ImportMatchingService
  # Recebe uma ImportedTransaction e sugere possíveis matches
  def initialize(imported_transaction)
    @imported_transaction = imported_transaction
  end

  def suggest_matches
    candidates = Transaction.where(user_id: @imported_transaction.import_session.user_id)
      .where('ABS(amount - ?) <= ?', @imported_transaction.amount.to_f.abs, [0.01, (@imported_transaction.amount.to_f.abs * 0.05)].max)
      .where('event_date BETWEEN ? AND ?',
        (@imported_transaction.event_date.to_date - 3),
        (@imported_transaction.event_date.to_date + 3))

    desc = @imported_transaction.description.to_s.downcase
    desc_norm = desc.gsub(/[^a-z0-9]/, '')
    candidates = candidates.select do |tx|
      tx_desc = tx.description.to_s.downcase.gsub(/[^a-z0-9]/, '')
      # Similaridade: pelo menos 6 caracteres em comum, ou similaridade >= 0.6
      (tx_desc[0,8] == desc_norm[0,8]) ||
      (tx_desc.include?(desc_norm[0,6])) ||
      (desc_norm.include?(tx_desc[0,6])) ||
      (string_similarity(tx_desc, desc_norm) >= 0.6)
    end

    # Parcelamento: regex para "05/12", "parcela 3 de 10", etc
    installment_match = nil
    if @imported_transaction.installment_info.present? || desc =~ /(\d{1,2}\/\d{1,2})|(parcela\s*\d+\s*(de|\/|-)\s*\d+)/i
      base = desc.gsub(/(\d{1,2}\/\d{1,2})|(parcela\s*\d+\s*(de|\/|-)\s*\d+)/i, '').strip
      installment_match = InstallmentPlan.where(user_id: @imported_transaction.import_session.user_id)
        .where('LOWER(name) LIKE ?', "%#{base[0,8].downcase}%")
        .first
    end

    # Recorrente: similaridade + valor aproximado
    recurring_match = RecurringCommitment.where(user_id: @imported_transaction.import_session.user_id)
      .where('LOWER(name) LIKE ?', "%#{desc[0,8].downcase}%")
      .select { |rc| (rc.expected_amount.to_f - @imported_transaction.amount.to_f).abs <= [0.01, (rc.expected_amount.to_f * 0.10)].max }
      .first

    {
      candidates: candidates,
      installment_plan: installment_match,
      recurring_commitment: recurring_match
    }
  end

  private

  # Similaridade de strings (Jaccard simples)
  def string_similarity(a, b)
    return 0 if a.blank? || b.blank?
    a_set = a.chars.to_set
    b_set = b.chars.to_set
    inter = a_set & b_set
    union = a_set | b_set
    inter.size.to_f / union.size
  end
end
