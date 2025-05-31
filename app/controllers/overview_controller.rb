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

    # Busca a conta de cartão de crédito
    @credit_card_account = Account.find_by(account_type: AccountType.find_by(code: "CREDIT"))
    # Busca a fatura do mês
    @credit_statement = CreditStatement.find_by(account: @credit_card_account, month: @month)

    @statement_due = @credit_statement&.due_on
    @statement_month_label = current_date.strftime("%B")

    @upcoming = Transaction.upcoming_payments(5)
    @category_ranking = category_ranking month_date
    @projected_balance = projected_balance @balance, @month
    @balance_alert = balance_alert @projected_balance
    today = Date.today
    @month_end = Date.new(today.year, today.month, -1)
    @chart_options = chart_options
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

def projected_balance(current_balance, month = nil)
  today = Date.today
  month ||= today.strftime('%Y-%m')
  month_end = Date.new(today.year, today.month, -1)

  # Some todos os lançamentos futuros até fim do mês
  future_transactions = Transaction
    .where("event_date > ?", today)
    .where("event_date <= ?", month_end)
    .confirmed
    .sum("CASE WHEN transaction_type = 'income' THEN amount ELSE -amount END")

  current_balance + future_transactions
end

def balance_alert(projected_balance)
  if projected_balance < 0
    "Atenção: balance projetado negativo após todos os compromissos!"
  elsif projected_balance < 1000 # valor de alerta personalizável
    "Alerta: balance projetado baixo!"
  else
    nil
  end
end