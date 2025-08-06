require 'ostruct'

class OverviewController < ApplicationController
  include FinancialConstants
  
  def index
    @month = params[:month] || Date.today.strftime('%Y-%m')
    month_date = Date.strptime(@month, "%Y-%m")
    
    # Filter by current user
    user_transactions = current_user_scope(Transaction)
    
    @transactions = user_transactions.in_competence_month(month_date)
    @income_total = user_transactions.in_competence_month(month_date).income.sum(:amount)
    @expense_total = user_transactions.in_competence_month(month_date).expense.sum(:amount)

    @balance = @income_total - @expense_total

    @category_totals = @transactions.joins(:category).group("categories.name").sum(:amount)

    current_date = month_date
    @prev_month = (current_date << 1).strftime("%Y-%m")
    @next_month = (current_date >> 1).strftime("%Y-%m")
    @selected_month_long = I18n.l(current_date, format: "%B de %Y")

    # === CREDIT CARD STATEMENTS ===
    load_credit_statements(month_date)

    # === UPCOMING COMMITMENTS ===
    @upcoming = user_transactions.upcoming_payments(10)
    
    # === ANALYSIS AND PROJECTIONS ===
    @category_ranking = category_ranking(month_date)
    @projected_balance = projected_balance(@balance, @month)
    @balance_alert = balance_alert(@projected_balance)
    
    # === AUTOMATIC PROJECTIONS BY CATEGORY ===
    @category_projections = generate_category_projections(month_date)
    
    # === CHART DATA ===
    today = Date.today
    @month_end = Date.new(today.year, today.month, -1)
    @chart_options = chart_options
    
    # === ADDITIONAL STATISTICS ===
    @monthly_stats = monthly_statistics(month_date)
    @savings_rate = calculate_savings_rate(@income_total, @expense_total)

    # === RECURRING COMMITMENTS PROJECTION ===
    @projected_transactions = RecurringProjectionService.call(as_of: month_date)
  end
end

def chart_options
  chart_data = generate_chart_data
  
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
  # Fetch all credit card statements for the current month
  @credit_statements = CreditStatement.includes(:account)
                                    .where(month: month_date.strftime('%Y-%m'))
                                    .order('accounts.name')
  
  # Statement statistics
  @credit_stats = {
    total_due: @credit_statements.sum(:amount_due),
    total_paid: @credit_statements.sum(:amount_paid),
    pending_count: @credit_statements.where(status: ['open', 'overdue']).count,
    overdue_count: @credit_statements.where(status: 'overdue').count
  }
  
  # Next statements due (next 30 days)
  @upcoming_statements = CreditStatement.includes(:account)
                                       .where(due_on: Date.today..30.days.from_now)
                                       .where.not(status: 'paid')
                                       .order(:due_on)
                                       .limit(5)
end

def monthly_statistics(month_date)
  prev_month = month_date - 1.month
  
  # Previous month data for comparison
  prev_income = Transaction.income.confirmed.in_competence_month(prev_month).sum(:amount)
  prev_expense = Transaction.expense.confirmed.in_competence_month(prev_month).sum(:amount)
  
  {
    income_growth: calculate_growth(@income_total, prev_income),
    expense_growth: calculate_growth(@expense_total, prev_expense),
    largest_expense: largest_expense_this_month(month_date),
    transaction_count: @transactions.confirmed.count,
    avg_transaction: FinancialConstants.safe_to_float(@transactions.confirmed.average(:amount), 0)
  }
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
  Transaction.expense.confirmed
             .in_competence_month(month_date)
             .order(amount: :desc)
             .first
end

def generate_chart_data
  # Generate data for the last 12 months
  end_date = Date.today
  start_date = end_date - 11.months
  
  months = []
  income_data = []
  expense_data = []
  balance_data = []
  accumulated_balance = 0
  
  (0..11).each do |i|
    month_date = start_date + i.months
    month_label = I18n.l(month_date, format: '%b/%y')
    
    # Calculate income and expenses for the month (filtered by user)
    user_transactions = current_user_scope(Transaction)
    income = user_transactions.income.confirmed.in_competence_month(month_date).sum(:amount)
    expense = user_transactions.expense.confirmed.in_competence_month(month_date).sum(:amount)
    
    # Calculate monthly balance
    monthly_balance = income - expense
    accumulated_balance += monthly_balance
    
    months << month_label
    income_data << FinancialConstants.safe_to_float(income)
    expense_data << FinancialConstants.safe_to_float(expense)
    balance_data << FinancialConstants.safe_to_float(accumulated_balance)
  end
  
  {
    categories: months,
    income_data: income_data,
    expense_data: expense_data,
    balance_data: balance_data
  }
end


def category_ranking(month_date = nil)
  month_date ||= Date.today
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
  future_income = future_transactions.where(transaction_type: "income").sum(:amount)
  future_expenses = future_transactions.where(transaction_type: "expense").sum(:amount)

  # Include projected transactions (recurring commitments projection)
  projected_transactions = RecurringProjectionService.call(as_of: month_date)
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
  current_user_scope(Category).map do |category|
    current_spent = current_user_scope(Transaction)
                      .in_competence_month(month_date)
                      .expense
                      .where(category: category)
                      .sum(:amount)
    
    projected = VariableExpenseAnalysisUnifiedService.projected_expense_for_category(category, 1, current_user)
    
    {
      category: category,
      current_spent: current_spent,
      projected: projected,
      remaining: projected - current_spent,
      percentage_used: projected > 0 ? FinancialConstants.calculate_percentage(current_spent, projected) : FinancialConstants::DEFAULT_PERCENTAGE
    }
  end.select { |projection| projection[:projected] > 0 }
     .sort_by { |projection| -projection[:projected] }
end