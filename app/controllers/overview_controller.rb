require 'ostruct'

class OverviewController < ApplicationController
  include FinancialConstants
  
  def index
    @month = params[:month] || Date.today.strftime('%Y-%m')
    month_date = Date.strptime(@month, "%Y-%m")
    
    # === MONTH SCOPES (single load to avoid N+1 / repeated aggregates) ===
    user_transactions = current_user_scope(Transaction)
    month_range = month_date.beginning_of_month..month_date.end_of_month
    # Preload category to avoid later joins
    month_transactions = user_transactions.where(event_date: month_range).includes(:category).to_a
    @transactions = month_transactions

    # Compute income / expense totals in memory (already loaded)
    income_transactions = month_transactions.select { |t| t.transaction_type == 'income' }
    expense_transactions = month_transactions.select { |t| t.transaction_type == 'expense' }
    @income_total = FinancialConstants.safe_to_float(income_transactions.sum { |t| t.amount })
    @expense_total = FinancialConstants.safe_to_float(expense_transactions.sum { |t| t.amount })
    @balance = @income_total - @expense_total

    # Category totals (name => amount) using loaded associations
    @category_totals = Hash.new(0)
    month_transactions.each do |t|
      next unless t.category
      @category_totals[t.category.name] += FinancialConstants.safe_to_float(t.amount)
    end

    current_date = month_date
    @prev_month = (current_date << 1).strftime("%Y-%m")
    @next_month = (current_date >> 1).strftime("%Y-%m")
    @selected_month_long = I18n.l(current_date, format: "%B de %Y")

    # === CREDIT CARD STATEMENTS ===
    load_credit_statements(month_date)

    # === UPCOMING COMMITMENTS ===
    @upcoming = user_transactions.upcoming_payments(10)
    
    # === ANALYSIS AND PROJECTIONS ===
  @category_ranking = category_ranking(month_date, month_transactions: month_transactions)
    @projected_balance = projected_balance(@balance, @month)
    @balance_alert = balance_alert(@projected_balance)
    
    # === AUTOMATIC PROJECTIONS BY CATEGORY ===
    @category_projections = generate_category_projections(month_date)
    
    # === CHART DATA ===
  today = Date.today
  @month_end = Date.new(today.year, today.month, -1)
  @chart_options = chart_options(user_transactions: user_transactions)
    
    # === ADDITIONAL STATISTICS ===
  @monthly_stats = monthly_statistics(month_date, month_transactions: month_transactions, user_transactions: user_transactions)
    @savings_rate = calculate_savings_rate(@income_total, @expense_total)

    # === RECURRING COMMITMENTS PROJECTION ===
  @projected_transactions = recurring_projections(as_of: month_date)

  # === ACCOUNTS (batch balance computation to avoid per-account queries) ===
  load_accounts_with_balances
  end
end

def chart_options(user_transactions:)
  chart_data = generate_chart_data(user_transactions: user_transactions)
  
  {
    chart: {
      type: 'line',
      height: 350,
      stacked: false,
      toolbar: {
        show: true,
        tools: {
          download: true,
          selection: false,
          zoom: false,
          zoomin: false,
          zoomout: false,
          pan: false,
          reset: false
        }
      }
    },
    colors: ['#10B981', '#EF4444', '#3B82F6'],
    series: [
      {
        name: 'Receitas',
        type: 'column',
        data: chart_data[:income_data]
      },
      {
        name: 'Despesas',
        type: 'column',
        data: chart_data[:expense_data]
      },
      {
        name: 'Saldo Acumulado',
        type: 'line',
        data: chart_data[:balance_data]
      }
    ],
    stroke: {
      width: [0, 0, 3],
      curve: 'smooth'
    },
    plotOptions: {
      bar: {
        columnWidth: '60%',
        dataLabels: {
          position: 'top'
        }
      }
    },
    xaxis: {
      categories: chart_data[:categories],
      title: {
        text: 'Mês'
      }
    },
    yaxis: [
      {
        title: {
          text: 'Valores (R$)'
        }
      }
    ],
    tooltip: {
      shared: true,
      intersect: false
    },
    legend: {
      position: 'top',
      horizontalAlign: 'left'
    },
    grid: {
      borderColor: '#e7e7e7',
      row: {
        colors: ['#f3f3f3', 'transparent'],
        opacity: 0.5
      }
    },
    responsive: [
      {
        breakpoint: 768,
        options: {
          chart: {
            height: 300
          },
          plotOptions: {
            bar: {
              columnWidth: '80%'
            }
          }
        }
      }
    ]
  }
end

private

def load_credit_statements(month_date)
  # Preload account and its type in a single pass
  @credit_statements = CreditStatement
                        .includes(:transactions, account: :account_type)
                        .where(month: month_date.strftime('%Y-%m'))
                        .order('accounts.name')

  # Aggregate statistics without extra queries
  stats = { total_due: 0, total_paid: 0, pending_count: 0, overdue_count: 0 }
  @credit_statements.each do |st|
    stats[:total_due] += FinancialConstants.safe_to_float(st.amount_due)
    stats[:total_paid] += FinancialConstants.safe_to_float(st.amount_paid)
    stats[:pending_count] += 1 if %w[open overdue].include?(st.status)
    stats[:overdue_count] += 1 if st.status == 'overdue'
  end
  @credit_stats = stats

  @upcoming_statements = CreditStatement
                           .includes(:transactions, account: :account_type)
                           .where(due_on: Date.today..30.days.from_now)
                           .where.not(status: 'paid')
                           .order(:due_on)
                           .limit(5)
end

def monthly_statistics(month_date, month_transactions:, user_transactions:)
  prev_month = month_date - 1.month
  prev_range = prev_month.beginning_of_month..prev_month.end_of_month
  # Load previous month confirmed transactions once
  prev_confirmed = user_transactions.where(event_date: prev_range, status: 'confirmed').to_a
  prev_income = prev_confirmed.select { |t| t.transaction_type == 'income' }.sum(&:amount)
  prev_expense = prev_confirmed.select { |t| t.transaction_type == 'expense' }.sum(&:amount)

  confirmed_month = month_transactions.select { |t| t.status == 'confirmed' }
  largest_expense = confirmed_month
                    .select { |t| t.transaction_type == 'expense' }
                    .max_by(&:amount)
  avg_amount = if confirmed_month.any?
                 confirmed_month.sum { |t| FinancialConstants.safe_to_float(t.amount) } / confirmed_month.size.to_f
               else
                 0
               end

  {
    income_growth: calculate_growth(@income_total, prev_income),
    expense_growth: calculate_growth(@expense_total, prev_expense),
    largest_expense: largest_expense,
    transaction_count: confirmed_month.size,
    avg_transaction: FinancialConstants.safe_to_float(avg_amount, 0)
  }
end

def load_accounts_with_balances
  @accounts = current_user.accounts.includes(:account_type).to_a
  return (@account_balances = {}) if @accounts.empty?
  ids = @accounts.map(&:id)
  # Single grouped query for confirmed entries
  sums = Entry.joins(:transaction_record)
              .where(account_id: ids, transactions: { status: 'confirmed' })
              .group(:account_id, :entry_type)
              .sum(:amount)
  @account_balances = {}
  @accounts.each do |acc|
    debit_total = FinancialConstants.safe_to_float(sums[[acc.id, 'debit']] || 0)
    credit_total = FinancialConstants.safe_to_float(sums[[acc.id, 'credit']] || 0)
    balance = if acc.account_type&.asset_type?
                debit_total - credit_total
              else
                credit_total - debit_total
              end
    @account_balances[acc.id] = balance
  end
end

  def calculate_savings_rate(income, expense)
    return FinancialConstants::DEFAULT_PERCENTAGE if income == 0
    FinancialConstants.calculate_percentage(income - expense, income)
  end

  def calculate_growth(current, previous)
    return 0 if previous == 0
    FinancialConstants.calculate_percentage(current - previous, previous)
  end

def largest_expense_this_month(month_date)
  # Deprecated: replaced by in-memory computation inside monthly_statistics
  nil
end

def generate_chart_data(user_transactions:)
  @__chart_data ||= begin
    ChartDataCache.fetch(current_user.id) do
      build_chart_data(user_transactions: user_transactions)
    end
  end
end

def build_chart_data(user_transactions:)
  ActiveSupport::Notifications.instrument('overview.build_chart_data') do
  end_date = Date.today
  start_date = end_date - 11.months
  range = start_date.beginning_of_month..end_date.end_of_month
  txs = user_transactions.where(status: 'confirmed', event_date: range).select(:id, :event_date, :amount, :transaction_type)
  months = []
  income_data = []
  expense_data = []
  balance_data = []
  accumulated_balance = 0
  (0..11).each do |i|
    m_date = start_date + i.months
    label = I18n.l(m_date, format: '%b/%y')
    month_range = m_date.beginning_of_month..m_date.end_of_month
    month_txs = txs.select { |t| t.event_date >= month_range.begin && t.event_date <= month_range.end }
    income = month_txs.select { |t| t.transaction_type == 'income' }.sum { |t| FinancialConstants.safe_to_float(t.amount) }
    expense = month_txs.select { |t| t.transaction_type == 'expense' }.sum { |t| FinancialConstants.safe_to_float(t.amount) }
    monthly_balance = income - expense
    accumulated_balance += monthly_balance
    months << label
    income_data << FinancialConstants.safe_to_float(income)
    expense_data << FinancialConstants.safe_to_float(expense)
    balance_data << FinancialConstants.safe_to_float(accumulated_balance)
  end
  { categories: months, income_data: income_data, expense_data: expense_data, balance_data: balance_data }
  end
end


def category_ranking(month_date = nil, month_transactions: nil)
  month_date ||= Date.today
  if month_transactions
    exp_confirmed = month_transactions.select { |t| t.transaction_type == 'expense' && t.status == 'confirmed' && t.category }
    grouped = Hash.new(0)
    exp_confirmed.each { |t| grouped[[t.category.id, t.category.name]] += FinancialConstants.safe_to_float(t.amount) }
    grouped.sort_by { |_k, v| -v }.first(5).map { |(id, name), amount| [OpenStruct.new(id: id, name: name), amount] }
  else
    current_user_scope(Transaction)
      .expense
      .in_competence_month(month_date)
      .confirmed
      .joins(:category)
      .group('categories.id, categories.name')
      .sum(:amount)
      .sort_by { |_key, amount| -amount }
      .first(5)
      .map { |(id, name), amount| [OpenStruct.new(id: id, name: name), amount] }
  end
end

# ...existing code...

private

def projected_balance(current_balance, month)
  base_balance = current_balance
  month_date = Date.strptime(month, "%Y-%m")
  end_of_month = month_date.end_of_month

  # Future transactions for current month (after today) - filtered by user
  future_transactions = current_user_scope(Transaction).where(
    status: ["pending", "confirmed"],
    event_date: (Date.current + 1.day)..end_of_month
  )
  future_grouped = future_transactions.group(:transaction_type).sum(:amount)
  future_income = FinancialConstants.safe_to_float(future_grouped['income'] || 0)
  future_expenses = FinancialConstants.safe_to_float(future_grouped['expense'] || 0)

  # Include projected transactions (recurring commitments projection)
  projected_transactions = recurring_projections(as_of: month_date)
  # Include future installments (competence perspective)
  installment_projections = InstallmentProjectionService.call(as_of: month_date)
  # Separate competence (event_date) vs cash (payment_date) if diverge in future
  projected_transactions += installment_projections
  projected_income = projected_transactions
    .select { |t| FinancialConstants.safe_to_decimal(t[:amount]) > 0 }
    .sum { |t| FinancialConstants.safe_to_decimal(t[:amount]) }
  projected_expenses = projected_transactions
    .select { |t| FinancialConstants.safe_to_decimal(t[:amount]) < 0 }
    .sum { |t| FinancialConstants.safe_to_decimal(t[:amount]).abs }

  projected = base_balance + future_income - future_expenses + projected_income - projected_expenses
  projected
end

# ...existing code...

  def balance_alert(projected_balance)
    if projected_balance < 0
      "Atenção: balance projetado negativo após todos os compromissos!"
    elsif projected_balance < FinancialConstants::LOW_BALANCE_THRESHOLD
      "Alerta: balance projetado baixo!"
    else
      nil
    end
  end

def generate_category_projections(month_date)
  CategoryProjectionCalculator.call(user: current_user, month_date: month_date)
end

def recurring_projections(as_of: Date.today)
  @recurring_projection_cache ||= {}
  user_key = current_user.id
  @recurring_projection_cache[user_key] ||= {}
  @recurring_projection_cache[user_key][as_of.to_date] ||= RecurringProjectionService.call(as_of: as_of)
end