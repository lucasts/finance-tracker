require 'rails_helper'

RSpec.describe RecurringProjectionService do
  let(:user) { create(:user) }
  let(:category) { create(:category) }
  let(:from_account) { create(:account, user: user) }
  let(:to_account) { create(:account, user: user) }

  before do
    # Garantir que o compromisso pertence ao usuário
    allow(RecurringCommitment).to receive(:active).and_return(RecurringCommitment.where(user: user, status: :active))
  end

  it 'projects future entries for an active monthly commitment' do
    commitment = create(:recurring_commitment, user: user, category: category, from_account: from_account, to_account: to_account, status: :active, recurrence_frequency: 'monthly', start_date: Date.new(2025, 6, 1), default_amount: 100)
    service = described_class.new(months_ahead: 3, as_of: Date.new(2025, 6, 9))
    projections = service.projected_transactions
    expect(projections).not_to be_empty
    expect(projections.first[:projected]).to be(true)
    expect(projections.first[:amount]).to eq(100)
  end

  it 'respects weekly frequency' do
    commitment = create(:recurring_commitment, user: user, category: category, from_account: from_account, to_account: to_account, status: :active, recurrence_frequency: 'weekly', start_date: Date.new(2025, 6, 1), default_amount: 50)
    service = described_class.new(months_ahead: 1, as_of: Date.new(2025, 6, 2))
    projections = service.projected_transactions.select { |p| p[:recurring_commitment_id] == commitment.id }
    expect(projections.map { |p| p[:date] }.uniq.size).to be > 3 # several weeks inside horizon
    step_sizes = projections.each_cons(2).map { |a, b| (b[:date] - a[:date]).to_i }
    expect(step_sizes.uniq).to eq([ 7 ])
  end

  it 'respects daily frequency and limits projections up to the horizon' do
    commitment = create(:recurring_commitment, user: user, category: category, from_account: from_account, to_account: to_account, status: :active, recurrence_frequency: 'daily', start_date: Date.new(2025, 6, 10), default_amount: 10)
    service = described_class.new(months_ahead: 0, as_of: Date.new(2025, 6, 10))
    projections = service.projected_transactions.select { |p| p[:recurring_commitment_id] == commitment.id }
  # horizon 0 months => end of current month; first projection is next day after seed
  end_of_month = Date.new(2025, 6, 30)
  expected_days = (Date.new(2025, 6, 11)..end_of_month).count
  expect(projections.size).to eq(expected_days)
  end

  it 'respects bimonthly frequency' do
    commitment = create(:recurring_commitment, user: user, category: category, from_account: from_account, to_account: to_account, status: :active, recurrence_frequency: 'bimonthly', start_date: Date.new(2025, 1, 15), default_amount: 200)
    service = described_class.new(months_ahead: 6, as_of: Date.new(2025, 2, 1))
    projections = service.projected_transactions.select { |p| p[:recurring_commitment_id] == commitment.id }
    dates = projections.map { |p| p[:date] }
    # Expect roughly 3 bimonthly occurrences within 6 months horizon
    expect(dates.size).to be_between(2, 4)
    interval_months = dates.each_cons(2).map { |a, b| ((b - a)/30).round }
    expect(interval_months.uniq).to include(2) # allow minor rounding variance
  end

  it 'respects semiannual frequency' do
    commitment = create(:recurring_commitment, user: user, category: category, from_account: from_account, to_account: to_account, status: :active, recurrence_frequency: 'semiannual', start_date: Date.new(2025, 1, 1), default_amount: 500)
    service = described_class.new(months_ahead: 12, as_of: Date.new(2025, 1, 15))
    projections = service.projected_transactions.select { |p| p[:recurring_commitment_id] == commitment.id }
    expect(projections.size).to be_between(2, 3) # two occurrences likely within a year horizon
  end

  it 'respects biennial frequency and does not exceed a short horizon' do
    commitment = create(:recurring_commitment, user: user, category: category, from_account: from_account, to_account: to_account, status: :active, recurrence_frequency: 'biennial', start_date: Date.new(2025, 1, 1), default_amount: 800)
    service = described_class.new(months_ahead: 3, as_of: Date.new(2025, 1, 10))
    projections = service.projected_transactions.select { |p| p[:recurring_commitment_id] == commitment.id }
    expect(projections).to be_empty # horizon too short for next biennial occurrence
  end

  it 'does not project for a closed commitment' do
    create(:recurring_commitment, user: user, category: category, from_account: from_account, to_account: to_account, status: :closed, recurrence_frequency: 'monthly', start_date: Date.new(2025, 6, 1), default_amount: 100)
    service = described_class.new(months_ahead: 3, as_of: Date.new(2025, 6, 9))
    projections = service.projected_transactions
    expect(projections).to be_empty
  end

  it 'updates the projection when the commitment amount is edited' do
    commitment = create(:recurring_commitment, user: user, category: category, from_account: from_account, to_account: to_account, status: :active, recurrence_frequency: 'monthly', start_date: Date.new(2025, 6, 1), default_amount: 100)
    service = described_class.new(months_ahead: 3, as_of: Date.new(2025, 6, 9))
    projections = service.projected_transactions
    expect(projections.first[:amount]).to eq(100)
    commitment.update(default_amount: 200)
    projections2 = service.projected_transactions
    expect(projections2.first[:amount]).to eq(200)
  end

  it 'removes projections when the commitment is paused' do
    commitment = create(:recurring_commitment, user: user, category: category, from_account: from_account, to_account: to_account, status: :active, recurrence_frequency: 'monthly', start_date: Date.new(2025, 6, 1), default_amount: 100)
    service = described_class.new(months_ahead: 3, as_of: Date.new(2025, 6, 9))
    expect(service.projected_transactions).not_to be_empty
    commitment.update(status: :paused)
    expect(service.projected_transactions).to be_empty
  end

  context 'boundary horizon' do
    it 'cuts off projections at the exact horizon date (does not extrapolate to end of next month)' do
      commitment = create(:recurring_commitment, user: user, category: category, from_account: from_account, to_account: to_account,
                                 status: :active, recurrence_frequency: 'weekly', start_date: Date.new(2025, 1, 1), default_amount: 25)
      as_of = Date.new(2025, 1, 10)
      months_ahead = 1
      horizon_limit = as_of.advance(months: months_ahead) # 2025-02-10
      projections = described_class.call(as_of: as_of, months_ahead: months_ahead)
      this_commitment = projections.select { |p| p[:recurring_commitment_id] == commitment.id }
      expect(this_commitment.all? { |p| p[:date] <= horizon_limit }).to be true
      expect(this_commitment.none? { |p| p[:date] > horizon_limit }).to be true
    end

    it 'includes an occurrence exactly at the horizon boundary' do
      commitment = create(:recurring_commitment, user: user, category: category, from_account: from_account, to_account: to_account,
                                 status: :active, recurrence_frequency: 'weekly', start_date: Date.new(2025, 3, 13), default_amount: 40)
      as_of = Date.new(2025, 3, 10)
      horizon_limit = as_of.advance(months: 1) # 2025-04-10
      projections = described_class.call(as_of: as_of, months_ahead: 1)
      this_commitment = projections.select { |p| p[:recurring_commitment_id] == commitment.id }
      dates = this_commitment.map { |p| p[:date] }
      expect(dates).to include(horizon_limit), "Esperava ocorrência em #{horizon_limit}, datas: #{dates.inspect}"
      expect(dates.any? { |d| d > horizon_limit }).to be false
    end
  end
end
