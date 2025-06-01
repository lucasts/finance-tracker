class OverviewController < ApplicationController
  def index
    @month = params[:month] || Date.today.strftime('%Y-%m')
    month_date = Date.strptime(@month, "%Y-%m")
    
    @transactions = Transaction.in_competence_month(month_date)
    @income_total = Transaction.in_competence_month(month_date).income.sum(:amount)
    @expense_total = Transaction.in_competence_month(month_date).expense.sum(:amount)

    @balance = @income_total - @expense_total

    @category_totals = @transactions.joins(:category).group("categories.name").sum(:amount)

    current_date = month_date
    @prev_month = (current_date << 1).strftime("%Y-%m")
    @next_month = (current_date >> 1).strftime("%Y-%m")
    @selected_month_long = I18n.l(current_date, format: "%B de %Y")

    # === FATURAS DE CARTÃO DE CRÉDITO ===
    load_credit_statements(month_date)

    # === PRÓXIMOS COMPROMISSOS ===
    @upcoming = Transaction.upcoming_payments(10)
    
    # === ANÁLISES E PROJEÇÕES ===
    @category_ranking = category_ranking(month_date)
    @projected_balance = projected_balance(@balance, @month)
    @balance_alert = balance_alert(@projected_balance)
    
    # === DADOS PARA GRÁFICOS ===
    today = Date.today
    @month_end = Date.new(today.year, today.month, -1)
    @chart_options = chart_options
    
    # === ESTATÍSTICAS ADICIONAIS ===
    @monthly_stats = monthly_statistics(month_date)
    @savings_rate = calculate_savings_rate(@income_total, @expense_total)
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
        },
        labels: {
          formatter: -> (value) { "R$ #{value.to_s.gsub(/\B(?=(\d{3})+(?!\d))/, '.')}" }
        }
      }
    ],
    tooltip: {
      shared: true,
      intersect: false,
      y: {
        formatter: -> (value, opts) do
          series_name = opts[:series][opts[:seriesIndex]][:name]
          "R$ #{value.to_s.gsub(/\B(?=(\d{3})+(?!\d))/, '.')}"
        end
      }
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
  # Buscar todas as faturas de cartão para o mês atual
  @credit_statements = CreditStatement.includes(:account)
                                    .where(month: month_date.strftime('%Y-%m'))
                                    .order('accounts.name')
  
  # Estatísticas das faturas
  @credit_stats = {
    total_due: @credit_statements.sum(:amount_due),
    total_paid: @credit_statements.sum(:amount_paid),
    pending_count: @credit_statements.where(status: ['open', 'overdue']).count,
    overdue_count: @credit_statements.where(status: 'overdue').count
  }
  
  # Próximas faturas a vencer (próximos 30 dias)
  @upcoming_statements = CreditStatement.includes(:account)
                                       .where(due_on: Date.today..30.days.from_now)
                                       .where.not(status: 'paid')
                                       .order(:due_on)
                                       .limit(5)
end

def monthly_statistics(month_date)
  prev_month = month_date - 1.month
  
  # Dados do mês anterior para comparação
  prev_income = Transaction.income.confirmed.in_competence_month(prev_month).sum(:amount)
  prev_expense = Transaction.expense.confirmed.in_competence_month(prev_month).sum(:amount)
  
  {
    income_growth: calculate_growth(@income_total, prev_income),
    expense_growth: calculate_growth(@expense_total, prev_expense),
    largest_expense: largest_expense_this_month(month_date),
    transaction_count: @transactions.confirmed.count,
    avg_transaction: @transactions.confirmed.average(:amount)&.to_f || 0
  }
end

def calculate_savings_rate(income, expense)
  return 0 if income == 0
  ((income - expense) / income * 100).round(1)
end

def calculate_growth(current, previous)
  return 0 if previous == 0
  ((current - previous) / previous * 100).round(1)
end

def largest_expense_this_month(month_date)
  Transaction.expense.confirmed
             .in_competence_month(month_date)
             .order(amount: :desc)
             .first
end

def generate_chart_data
  # Gera dados para os últimos 12 meses
  end_date = Date.today
  start_date = end_date - 11.months
  
  months = []
  income_data = []
  expense_data = []
  balance_data = []
  accumulated_balance = 0
  
  (0..11).each do |i|
    month_date = start_date + i.months
    month_str = month_date.strftime('%Y-%m')
    month_label = I18n.l(month_date, format: '%b/%y')
    
    # Calcula receitas e despesas do mês
    income = Transaction.income.confirmed.in_competence_month(month_date).sum(:amount)
    expense = Transaction.expense.confirmed.in_competence_month(month_date).sum(:amount)
    
    # Calcula saldo do mês
    monthly_balance = income - expense
    accumulated_balance += monthly_balance
    
    months << month_label
    income_data << income.to_f
    expense_data << expense.to_f
    balance_data << accumulated_balance.to_f
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
  Transaction
    .expense
    .in_competence_month(month_date)
    .confirmed
    .group(:category_id)
    .sum(:amount)
    .sort_by { |_cat_id, amount| -amount }
    .first(5)
    .map { |cat_id, amount| [Category.find(cat_id), amount] }
end

# ...existing code...

private

def projected_balance(current_balance, month)
  # Saldo atual do mês
  base_balance = current_balance
  
  # Buscar transações futuras até o final do mês
  month_date = Date.strptime(month, "%Y-%m")
  end_of_month = month_date.end_of_month
  
  # Transações futuras do mês atual (depois de hoje)
  future_transactions = Transaction.where(
    status: ["pending", "confirmed"],
    event_date: (Date.current + 1.day)..end_of_month
  )
  
  # Separar receitas e despesas usando transaction_type
  future_income = future_transactions.where(transaction_type: "income").sum(:amount)
  future_expenses = future_transactions.where(transaction_type: "expense").sum(:amount)
  
  # Calcular projeção
  projected = base_balance + future_income - future_expenses
  
  projected
end

# ...existing code...

def balance_alert(projected_balance)
  if projected_balance < 0
    "Atenção: balance projetado negativo após todos os compromissos!"
  elsif projected_balance < 1000 # valor de alerta personalizável
    "Alerta: balance projetado baixo!"
  else
    nil
  end
end