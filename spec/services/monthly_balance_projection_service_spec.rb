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
           event_date: Date.new(2025, 8, 5), payment_date: Date.new(2025, 9, 1), category: category_income)
    # Realized cash only (payment_date in month <= as_of, event previous month)
    create(:transaction, :expense, :confirmed, user: user, amount: 300,
           event_date: Date.new(2025, 7, 28), payment_date: Date.new(2025, 8, 3), category: category_expense)
    # Future (both competence & cash later in month)
    create(:transaction, :expense, :pending, user: user, amount: 200,
           event_date: Date.new(2025, 8, 20), payment_date: Date.new(2025, 8, 20), category: category_expense)
  end

  it 'calculates competency and cash projections separately for the month' do
    result = described_class.call(user: user, month_date: month_date, as_of: as_of)

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

  it 'includes projections from recurring commitments and future installments' do
  # Recurring commitment starting before as_of
  _commitment = create(:recurring_commitment, user: user, category: category_expense,
                             from_account: asset_account, to_account: expense_account,
                             start_date: Date.new(2025, 8, 1), default_amount: 50,
                             recurrence_frequency: 'weekly', status: :active)
  _plan = create(:installment_plan, user: user, category: category_expense,
                        from_account: asset_account, to_account: expense_account,
                        installment_count: 5, total_amount: 500, starts_on: Date.new(2025, 8, 1), recurrence_frequency: 'weekly')

    result = described_class.call(user: user, month_date: month_date, as_of: as_of)
    competence = result[:competence]

    # Expect at least one projected recurring expense (weekly commitments after as_of)
    expect(competence[:projected_recurring_expense]).to be > 0
    # Expect projected installments (remaining installments all future at as_of)
    expect(competence[:projected_installment_expense]).to be > 0
  end

  context 'end-of-month boundary' do
    it 'does not count future projections when as_of is the last day of the month (no remaining days)' do
      end_of_month = Date.new(2025, 8, 31)
      user2 = create(:user)
      category_exp = create(:category, :expense, user: user2)
      asset_acc = create(:account, :asset, user: user2)
      dest_acc = create(:account, :expense_destination, user: user2)
      # Compromisso semanal que teria próxima ocorrência após o fim do mês
      create(:recurring_commitment, user: user2, category: category_exp,
             from_account: asset_acc, to_account: dest_acc,
             start_date: Date.new(2025, 8, 7), default_amount: 80,
             recurrence_frequency: 'weekly', status: :active)
      # Plano de parcelas começando exatamente no último dia do mês
      create(:installment_plan, user: user2, category: category_exp,
             from_account: asset_acc, to_account: dest_acc,
             installment_count: 3, total_amount: 300, starts_on: end_of_month,
             recurrence_frequency: 'monthly')

      result = described_class.call(user: user2, month_date: end_of_month, as_of: end_of_month)
      comp = result[:competence]
      cash = result[:cash]
      # Sem dias futuros restantes → futuras parcelas/recorrentes 0
      expect(comp[:projected_recurring_expense]).to eq(0)
      expect(comp[:projected_installment_expense]).to eq(0)
      expect(cash[:projected_recurring_expense]).to eq(0)
      expect(cash[:projected_installment_expense]).to eq(0)
      expect(comp[:future_expense]).to eq(0)
      expect(cash[:future_expense]).to eq(0)
    end
  end
end
