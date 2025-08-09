require 'rails_helper'

RSpec.describe InstallmentProjectionService do
  let(:user) { create(:user) }
  let(:category) { create(:category, user: user) }
  let(:from_account) { create(:account, user: user) }
  let(:to_account) { create(:account, user: user) }

  it 'projeta parcelas futuras ausentes dentro do horizonte padrão' do
    plan = create(:installment_plan, user: user, category: category, from_account: from_account, to_account: to_account,
                                     installment_count: 6, total_amount: 600.0, starts_on: Date.new(2025, 1, 10), recurrence_frequency: 'monthly')
    # Simula que 2 parcelas já existem
    create(:transaction, :installment, installment_plan: plan, installment_number: 1, user: user, amount: 100, event_date: Date.new(2025,1,10), payment_date: Date.new(2025,1,10))
    create(:transaction, :installment, installment_plan: plan, installment_number: 2, user: user, amount: 100, event_date: Date.new(2025,2,10), payment_date: Date.new(2025,2,10))

    as_of = Date.new(2025, 2, 15)
    projections = InstallmentProjectionService.call(as_of: as_of, months_ahead: 4)
    this_plan = projections.select { |p| p[:installment_plan_id] == plan.id }

    # Deve projetar parcelas 3..6
    expect(this_plan.map { |p| p[:installment_number] }).to eq([3,4,5,6])
    expect(this_plan.size).to eq(4)
    # Datas devem estar no horizonte e >= as_of
    expect(this_plan.all? { |p| p[:date] >= as_of }).to be true
  end

  it 'não projeta quando valor por parcela não positivo' do
    plan = build(:installment_plan, user: user, category: category, from_account: from_account, to_account: to_account,
                                    installment_count: 3, total_amount: 0, starts_on: Date.new(2025, 1, 1), recurrence_frequency: 'monthly')
    expect(plan).not_to be_valid # validação de modelo
    # Sem planos válidos ativos não há projeções
    projections = InstallmentProjectionService.call(as_of: Date.new(2025,1,15))
    expect(projections).to be_empty
  end

  it 'respeita horizonte zero (fim do mês atual) projetando próximas parcelas dentro do mês' do
    as_of = Date.new(2025,8,5)
    plan = create(:installment_plan, user: user, category: category, from_account: from_account, to_account: to_account,
                                     installment_count: 12, total_amount: 1200, starts_on: Date.new(2025, 8, 1), recurrence_frequency: 'monthly')
    projections = InstallmentProjectionService.call(as_of: as_of, months_ahead: 0)
    plan_proj = projections.select { |p| p[:installment_plan_id] == plan.id }
  expect(plan_proj.map { |p| p[:installment_number] }).to include(1)
  expect(plan_proj.all? { |p| p[:date].month == 8 }).to be true
  end
end
