require 'rails_helper'

RSpec.describe MonthlyBalanceProjectionService do
  let(:user) { create(:user) }
  let(:category_income) { create(:category, :income, user: user) }
  let(:category_expense) { create(:category, :expense, user: user) }
  let(:asset_account) { create(:account, :asset, user: user) }
  let(:expense_account) { create(:account, :expense_destination, user: user) }
  let(:month_date) { Date.new(2025, 8, 1) }
  let(:as_of) { Date.new(2025, 8, 10) }

  before do
    # Realized competence only (event_date in month <= as_of, payment later)
    create(:transaction, :income, :confirmed, user: user, amount: 1000,
           event_date: Date.new(2025,8,5), payment_date: Date.new(2025,9,1), category: category_income)
    # Realized cash only (payment_date in month <= as_of, event previous month)
    create(:transaction, :expense, :confirmed, user: user, amount: 300,
           event_date: Date.new(2025,7,28), payment_date: Date.new(2025,8,3), category: category_expense)
    # Future (both competence & cash later in month)
    create(:transaction, :expense, :pending, user: user, amount: 200,
           event_date: Date.new(2025,8,20), payment_date: Date.new(2025,8,20), category: category_expense)
  end

  it 'calcula separadamente projeção competência e caixa para o mês' do
    result = MonthlyBalanceProjectionService.call(user: user, month_date: month_date, as_of: as_of)

    competence = result[:competence]
    cash = result[:cash]

    # Base competence should include 1000 income (event_date <= as_of) and exclude 300 expense (event_date prev month)
    expect(competence[:base_income]).to eq(1000)
    expect(competence[:base_expense]).to eq(0)

    # Base cash should include 300 expense (payment_date <= as_of) and exclude 1000 income (payment in future)
    expect(cash[:base_income]).to eq(0)
    expect(cash[:base_expense]).to eq(300)

    # Future competence should include the pending expense 200
    expect(competence[:future_expense]).to eq(200)
    # Future cash similarly
    expect(cash[:future_expense]).to eq(200)

    # Projected balances computed correctly
    expected_competence_balance = (competence[:base_income] - competence[:base_expense]) - competence[:future_expense]
    expected_cash_balance = (cash[:base_income] - cash[:base_expense]) - cash[:future_expense]

    expect(competence[:projected_balance]).to eq(expected_competence_balance)
    expect(cash[:projected_balance]).to eq(expected_cash_balance)
  end

  it 'inclui projeções de recorrentes e parcelas futuras' do
    # Recurring commitment starting before as_of
  _commitment = create(:recurring_commitment, user: user, category: category_expense,
                             from_account: asset_account, to_account: expense_account,
                             start_date: Date.new(2025,8,1), default_amount: 50,
                             recurrence_frequency: 'weekly', status: :active)
  _plan = create(:installment_plan, user: user, category: category_expense,
                        from_account: asset_account, to_account: expense_account,
                        installment_count: 5, total_amount: 500, starts_on: Date.new(2025,8,1), recurrence_frequency: 'weekly')

    result = MonthlyBalanceProjectionService.call(user: user, month_date: month_date, as_of: as_of)
    competence = result[:competence]

    # Expect at least one projected recurring expense (weekly commitments after as_of)
    expect(competence[:projected_recurring_expense]).to be > 0
    # Expect projected installments (remaining installments all future at as_of)
    expect(competence[:projected_installment_expense]).to be > 0
  end
end
