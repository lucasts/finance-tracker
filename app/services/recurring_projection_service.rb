# frozen_string_literal: true

# Service to generate projections of future transactions from recurring commitments
class RecurringProjectionService
  DEFAULT_MONTHS_AHEAD = 3

  def initialize(months_ahead: DEFAULT_MONTHS_AHEAD, as_of: Date.today)
    @months_ahead = months_ahead
    @as_of = as_of
  end

  # Returns an array of hashes representing projected transactions (not persisted)
  def projected_transactions
    RecurringCommitment.where(status: :active).flat_map do |commitment|
      project_commitment(commitment)
    end
  end

  private

  def project_commitment(commitment)
    # Find the last real transaction for this commitment
    last_real = commitment.transactions.order(:event_date).last
    start_date = last_real&.event_date || commitment.start_date
    end_date = [@as_of.advance(months: @months_ahead).end_of_month, commitment.end_date].compact.min
    return [] if start_date > end_date

    # Generate future dates for projection
    dates = []
    current = start_date.advance(months: 1)
    while current <= end_date
      dates << current
      current = current.advance(months: 1)
    end

    dates.map do |date|
      {
        id: "proj-#{commitment.id}-#{date}",
        date: date,
        amount: commitment.default_amount,
        description: commitment.name,
        category_id: commitment.category_id,
        account_id: commitment.from_account_id, # Mantém compatibilidade
        from_account_id: commitment.from_account_id, # Para compatibilidade legacy
        to_account_id: commitment.to_account_id,
        recurring_commitment_id: commitment.id,
        projected: true
      }
    end
  end
end
