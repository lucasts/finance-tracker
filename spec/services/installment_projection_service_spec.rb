require 'rails_helper'

RSpec.describe InstallmentProjectionService do
  let(:user) { create(:user) }
  let(:category) { create(:category, user: user) }
  let(:from_account) { create(:account, user: user) }
  let(:to_account) { create(:account, user: user) }

  it 'projects missing future installments within the default horizon' do
    plan = create(:installment_plan, user: user, category: category, from_account: from_account, to_account: to_account,
                                     installment_count: 6, total_amount: 600.0, starts_on: Date.new(2025, 1, 10), recurrence_frequency: 'monthly')
    # Simula que 2 parcelas já existem
    create(:transaction, :installment, installment_plan: plan, installment_number: 1, user: user, amount: 100, event_date: Date.new(2025, 1, 10), payment_date: Date.new(2025, 1, 10))
    create(:transaction, :installment, installment_plan: plan, installment_number: 2, user: user, amount: 100, event_date: Date.new(2025, 2, 10), payment_date: Date.new(2025, 2, 10))

    as_of = Date.new(2025, 2, 15)
    projections = described_class.call(as_of: as_of, months_ahead: 4)
    this_plan = projections.select { |p| p[:installment_plan_id] == plan.id }

    # Deve projetar parcelas 3..6
    expect(this_plan.map { |p| p[:installment_number] }).to eq([ 3, 4, 5, 6 ])
    expect(this_plan.size).to eq(4)
    # Datas devem estar no horizonte e >= as_of
    expect(this_plan.all? { |p| p[:date] >= as_of }).to be true
  end

  it 'does not project when the per-installment amount is non-positive' do
    plan = build(:installment_plan, user: user, category: category, from_account: from_account, to_account: to_account,
                                    installment_count: 3, total_amount: 0, starts_on: Date.new(2025, 1, 1), recurrence_frequency: 'monthly')
    expect(plan).not_to be_valid # validação de modelo
    # Sem planos válidos ativos não há projeções
    projections = described_class.call(as_of: Date.new(2025, 1, 15))
    expect(projections).to be_empty
  end

  it 'respects a zero-month horizon (end of current month), projecting only future installments within that month' do
    as_of = Date.new(2025, 8, 5)
    plan = create(:installment_plan, user: user, category: category, from_account: from_account, to_account: to_account,
                                     installment_count: 5, total_amount: 500, starts_on: Date.new(2025, 8, 6), recurrence_frequency: 'weekly')
    projections = described_class.call(as_of: as_of, months_ahead: 0)
    plan_proj = projections.select { |p| p[:installment_plan_id] == plan.id }
    # First projected installment is number 1 (since starts_on > as_of, it's future)
    expect(plan_proj.map { |p| p[:installment_number] }).to include(1)
    # All projected installments are within August horizon (months_ahead 0 => end_of_month)
    expect(plan_proj.all? { |p| p[:date].month == 8 }).to be true
    # No installment date earlier than as_of
    expect(plan_proj.none? { |p| p[:date] < as_of }).to be true
  end

  context 'horizonte limites' do
    it 'cuts off projections exactly on the horizon day boundary (months_ahead > 0)' do
      as_of = Date.new(2025, 1, 15)
      # months_ahead 1 => horizonte esperado até 2025-02-15 (não o fim inteiro de fevereiro)
      plan = create(:installment_plan, user: user, category: category, from_account: from_account, to_account: to_account,
                                       installment_count: 12, total_amount: 1200, starts_on: Date.new(2025, 1, 16), recurrence_frequency: 'weekly')

      projections = described_class.call(as_of: as_of, months_ahead: 1)
      this_plan = projections.select { |p| p[:installment_plan_id] == plan.id }
      horizon_cutoff = as_of.advance(months: 1) # 2025-02-15
      # Todas as parcelas projetadas devem estar <= cutoff
      expect(this_plan.all? { |p| p[:date] <= horizon_cutoff }).to be true
      # E não deve existir parcela além do cutoff (ex: 2025-02-16 ou posteriores)
      expect(this_plan.none? { |p| p[:date] > horizon_cutoff }).to be true
    end

    it 'inclui parcela exatamente no limite do horizonte' do
      as_of = Date.new(2025, 3, 10)
      # Criar plano semanal iniciando de forma que uma parcela caia exatamente em 2025-04-10 (horizonte 1 mês)
      plan = create(:installment_plan, user: user, category: category, from_account: from_account, to_account: to_account,
                                       installment_count: 10, total_amount: 1000, starts_on: Date.new(2025, 3, 13), recurrence_frequency: 'weekly')
      horizon_limit = as_of.advance(months: 1) # 2025-04-10
      projections = described_class.call(as_of: as_of, months_ahead: 1)
      this_plan = projections.select { |p| p[:installment_plan_id] == plan.id }
      dates = this_plan.map { |p| p[:date] }
      expect(dates).to include(horizon_limit), "Esperava incluir parcela no limite #{horizon_limit}, datas: #{dates.inspect}"
      expect(dates.any? { |d| d > horizon_limit }).to be false
    end
  end
end
