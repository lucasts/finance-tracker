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

  it 'projeta lançamentos futuros para compromisso mensal ativo' do
    commitment = create(:recurring_commitment, user: user, category: category, from_account: from_account, to_account: to_account, status: :active, recurrence_frequency: 'monthly', start_date: Date.new(2025, 6, 1), default_amount: 100)
    service = RecurringProjectionService.new(months_ahead: 3, as_of: Date.new(2025, 6, 9))
    projections = service.projected_transactions
    expect(projections).not_to be_empty
    expect(projections.first[:projected]).to eq(true)
    expect(projections.first[:amount]).to eq(100)
  end

  it 'respeita frequência semanal' do
    commitment = create(:recurring_commitment, user: user, category: category, from_account: from_account, to_account: to_account, status: :active, recurrence_frequency: 'weekly', start_date: Date.new(2025, 6, 1), default_amount: 50)
    service = RecurringProjectionService.new(months_ahead: 1, as_of: Date.new(2025, 6, 2))
    projections = service.projected_transactions.select { |p| p[:recurring_commitment_id] == commitment.id }
    expect(projections.map { |p| p[:date] }.uniq.size).to be > 3 # several weeks inside horizon
    step_sizes = projections.each_cons(2).map { |a, b| (b[:date] - a[:date]).to_i }
    expect(step_sizes.uniq).to eq([7])
  end

  it 'respeita frequência diária limitando até o horizonte' do
    commitment = create(:recurring_commitment, user: user, category: category, from_account: from_account, to_account: to_account, status: :active, recurrence_frequency: 'daily', start_date: Date.new(2025, 6, 10), default_amount: 10)
    service = RecurringProjectionService.new(months_ahead: 0, as_of: Date.new(2025, 6, 10))
    projections = service.projected_transactions.select { |p| p[:recurring_commitment_id] == commitment.id }
  # horizon 0 months => end of current month; first projection is next day after seed
  end_of_month = Date.new(2025, 6, 30)
  expected_days = (Date.new(2025,6,11)..end_of_month).count
  expect(projections.size).to eq(expected_days)
  end

  it 'respeita frequência bimestral (bimonthly)' do
    commitment = create(:recurring_commitment, user: user, category: category, from_account: from_account, to_account: to_account, status: :active, recurrence_frequency: 'bimonthly', start_date: Date.new(2025, 1, 15), default_amount: 200)
    service = RecurringProjectionService.new(months_ahead: 6, as_of: Date.new(2025, 2, 1))
    projections = service.projected_transactions.select { |p| p[:recurring_commitment_id] == commitment.id }
    dates = projections.map { |p| p[:date] }
    # Expect roughly 3 bimonthly occurrences within 6 months horizon
    expect(dates.size).to be_between(2,4)
    interval_months = dates.each_cons(2).map { |a,b| ((b - a)/30).round }
    expect(interval_months.uniq).to include(2) # allow minor rounding variance
  end

  it 'respeita frequência semestral (semiannual)' do
    commitment = create(:recurring_commitment, user: user, category: category, from_account: from_account, to_account: to_account, status: :active, recurrence_frequency: 'semiannual', start_date: Date.new(2025, 1, 1), default_amount: 500)
    service = RecurringProjectionService.new(months_ahead: 12, as_of: Date.new(2025, 1, 15))
    projections = service.projected_transactions.select { |p| p[:recurring_commitment_id] == commitment.id }
    expect(projections.size).to be_between(2,3) # two occurrences likely within a year horizon
  end

  it 'respeita frequência bienal (biennial) não excedendo horizonte curto' do
    commitment = create(:recurring_commitment, user: user, category: category, from_account: from_account, to_account: to_account, status: :active, recurrence_frequency: 'biennial', start_date: Date.new(2025, 1, 1), default_amount: 800)
    service = RecurringProjectionService.new(months_ahead: 3, as_of: Date.new(2025, 1, 10))
    projections = service.projected_transactions.select { |p| p[:recurring_commitment_id] == commitment.id }
    expect(projections).to be_empty # horizon too short for next biennial occurrence
  end

  it 'não projeta para compromisso encerrado' do
    create(:recurring_commitment, user: user, category: category, from_account: from_account, to_account: to_account, status: :closed, recurrence_frequency: 'monthly', start_date: Date.new(2025, 6, 1), default_amount: 100)
    service = RecurringProjectionService.new(months_ahead: 3, as_of: Date.new(2025, 6, 9))
    projections = service.projected_transactions
    expect(projections).to be_empty
  end

  it 'atualiza projeção ao editar valor do compromisso' do
    commitment = create(:recurring_commitment, user: user, category: category, from_account: from_account, to_account: to_account, status: :active, recurrence_frequency: 'monthly', start_date: Date.new(2025, 6, 1), default_amount: 100)
    service = RecurringProjectionService.new(months_ahead: 3, as_of: Date.new(2025, 6, 9))
    projections = service.projected_transactions
    expect(projections.first[:amount]).to eq(100)
    commitment.update(default_amount: 200)
    projections2 = service.projected_transactions
    expect(projections2.first[:amount]).to eq(200)
  end

  it 'remove projeção ao pausar compromisso' do
    commitment = create(:recurring_commitment, user: user, category: category, from_account: from_account, to_account: to_account, status: :active, recurrence_frequency: 'monthly', start_date: Date.new(2025, 6, 1), default_amount: 100)
    service = RecurringProjectionService.new(months_ahead: 3, as_of: Date.new(2025, 6, 9))
    expect(service.projected_transactions).not_to be_empty
    commitment.update(status: :paused)
    expect(service.projected_transactions).to be_empty
  end
end
