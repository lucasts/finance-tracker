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

  it 'não projeta para compromisso encerrado' do
    commitment = create(:recurring_commitment, user: user, category: category, from_account: from_account, to_account: to_account, status: :closed, recurrence_frequency: 'monthly', start_date: Date.new(2025, 6, 1), default_amount: 100)
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
