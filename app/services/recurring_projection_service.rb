# frozen_string_literal: true

# Service to generate projections of future transactions from recurring commitments
class RecurringProjectionService
  DEFAULT_HORIZON_MONTHS = 3

  # Public API: horizon defined in months but converts into an absolute end date
  def self.call(months_ahead: DEFAULT_HORIZON_MONTHS, as_of: Date.today)
    new(months_ahead: months_ahead, as_of: as_of).projected_transactions
  end

  def initialize(months_ahead: DEFAULT_HORIZON_MONTHS, as_of: Date.today)
    @as_of = as_of
  horizon_date = as_of.advance(months: months_ahead)
  # Horizon semantics (exact-date mode — decided 2025-08, confirmed 2026-03):
  #   months_ahead > 0  → exact day boundary (e.g. Mar 15 + 3 months = Jun 15)
  #   months_ahead == 0 → current month focus (end_of_month)
  # A month_end rounding mode was evaluated and rejected for consistency.
  # See docs/TECHNICAL_SPECIFICATION.md § Projection Services Architecture.
  horizon_date = as_of.end_of_month if months_ahead.zero?
  @horizon_end = horizon_date.end_of_day
  end

  # Returns array of hash projections (non‑persisted)
  def projected_transactions
    RecurringCommitment.where(status: :active).flat_map { |c| project_commitment(c) }
  end

  private

  # Determine next occurrence increment based on frequency
  def advance_date(date, frequency)
    case frequency
    when "daily" then date + 1.day
    when "weekly" then date + 1.week
    when "fortnightly" then date + 14.days
    when "monthly" then date + 1.month
    when "bimonthly" then date + 2.months
    when "quarterly" then date + 3.months
    when "semiannual" then date + 6.months
    when "annual", "yearly" then date + 1.year
    when "biennial" then date + 2.years
    else date + 1.month
    end
  end

  def project_commitment(commitment)
    freq = commitment.recurrence_frequency
    return [] unless RecurringCommitment::SUPPORTED_FREQUENCIES.include?(freq)
    return [] unless commitment.active_on?(@as_of) || commitment.start_date <= @horizon_end

    last_real_tx = commitment.transactions.order(:event_date).last
    seed_date = last_real_tx&.event_date || commitment.start_date
    # If as_of is after seed_date, move seed forward to nearest occurrence before or equal to as_of
    # Advance seed forward but keep last occurrence not after as_of
    loop do
      next_occ = advance_date(seed_date, freq)
      break if next_occ > @as_of
      seed_date = next_occ
    end
    current = advance_date(seed_date, freq)
    projections = []

  while current <= @horizon_end.to_date && (commitment.end_date.nil? || current <= commitment.end_date)
      break if commitment.default_amount.nil? && commitment.transactions.none? # nothing to project without amount baseline
      projections << build_projection_hash(commitment, current)
      current = advance_date(current, freq)
  end

    projections
  end

  def build_projection_hash(commitment, date)
    {
      id: "proj-#{commitment.id}-#{date}",
      date: date,
      amount: commitment.default_amount,
      description: commitment.name,
      category_id: commitment.category_id,
      account_id: commitment.from_account_id,
      to_account_id: commitment.to_account_id,
      recurring_commitment_id: commitment.id,
      projected: true,
      frequency: commitment.recurrence_frequency
    }
  end
end
