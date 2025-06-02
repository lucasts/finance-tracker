# Service para análise de gastos variáveis
# Analisa padrões de gastos e fornece insights sobre variabilidade de despesas
class VariableExpenseAnalyzerService
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :account_id, :integer
  attribute :category_id, :integer
  attribute :start_date, :date, default: -> { 6.months.ago }
  attribute :end_date, :date, default: -> { Date.current }
  attribute :analysis_type, :string, default: 'monthly'

  validates :start_date, :end_date, presence: true
  validates :analysis_type, inclusion: { in: %w[daily weekly monthly yearly] }
  validate :end_date_after_start_date

  def call
    return { success: false, errors: errors.full_messages } unless valid?

    {
      success: true,
      data: {
        summary: generate_summary,
        trend_analysis: generate_trend_analysis,
        variability_metrics: calculate_variability_metrics,
        period_comparison: generate_period_comparison,
        category_breakdown: generate_category_breakdown,
        predictions: generate_predictions,
        recommendations: generate_recommendations
      }
    }
  end

  # Método de conveniência para análise por conta
  def self.analyze_account(account_id, options = {})
    new(options.merge(account_id: account_id)).call
  end

  # Método de conveniência para análise por categoria
  def self.analyze_category(category_id, options = {})
    new(options.merge(category_id: category_id)).call
  end

  # Método de conveniência para análise geral
  def self.analyze_general(options = {})
    new(options).call
  end

  private

  def base_transactions
    @base_transactions ||= begin
      transactions = Transaction.where(date: start_date..end_date)
      transactions = transactions.where(account_id: account_id) if account_id.present?
      transactions = transactions.where(category_id: category_id) if category_id.present?
      transactions.includes(:account, :category)
    end
  end

  def generate_summary
    transactions = base_transactions
    
    {
      total_transactions: transactions.count,
      total_amount: transactions.sum(:amount),
      average_amount: transactions.average(:amount)&.round(2) || 0,
      date_range: {
        start_date: start_date,
        end_date: end_date,
        days: (end_date - start_date).to_i + 1
      },
      transaction_types: transactions.group(:transaction_type).sum(:amount)
    }
  end

  def generate_trend_analysis
    case analysis_type
    when 'daily'
      group_by_day
    when 'weekly'
      group_by_week
    when 'monthly'
      group_by_month
    when 'yearly'
      group_by_year
    end
  end

  def group_by_month
    monthly_data = base_transactions
                    .group_by_month(:date, range: start_date..end_date)
                    .group(:transaction_type)
                    .sum(:amount)

    months = []
    current_month = start_date.beginning_of_month

    while current_month <= end_date.end_of_month
      month_key = current_month.strftime('%Y-%m')
      
      expense_amount = monthly_data[[current_month, 'expense']] || 0
      income_amount = monthly_data[[current_month, 'income']] || 0
      transfer_amount = monthly_data[[current_month, 'transfer']] || 0
      
      months << {
        period: month_key,
        date: current_month,
        expense: expense_amount,
        income: income_amount,
        transfer: transfer_amount,
        net: income_amount - expense_amount,
        total_transactions: base_transactions.where(
          date: current_month.beginning_of_month..current_month.end_of_month
        ).count
      }
      
      current_month = current_month.next_month
    end

    months
  end

  def group_by_week
    weekly_data = base_transactions
                   .group_by_week(:date, range: start_date..end_date)
                   .group(:transaction_type)
                   .sum(:amount)

    weeks = []
    current_week = start_date.beginning_of_week

    while current_week <= end_date.end_of_week
      week_key = "#{current_week.strftime('%Y-W%U')}"
      
      expense_amount = weekly_data[[current_week, 'expense']] || 0
      income_amount = weekly_data[[current_week, 'income']] || 0
      transfer_amount = weekly_data[[current_week, 'transfer']] || 0
      
      weeks << {
        period: week_key,
        date: current_week,
        expense: expense_amount,
        income: income_amount,
        transfer: transfer_amount,
        net: income_amount - expense_amount,
        total_transactions: base_transactions.where(
          date: current_week..current_week.end_of_week
        ).count
      }
      
      current_week = current_week.next_week
    end

    weeks
  end

  def group_by_day
    daily_data = base_transactions
                  .group_by_day(:date, range: start_date..end_date)
                  .group(:transaction_type)
                  .sum(:amount)

    days = []
    current_date = start_date

    while current_date <= end_date
      day_key = current_date.strftime('%Y-%m-%d')
      
      expense_amount = daily_data[[current_date, 'expense']] || 0
      income_amount = daily_data[[current_date, 'income']] || 0
      transfer_amount = daily_data[[current_date, 'transfer']] || 0
      
      days << {
        period: day_key,
        date: current_date,
        expense: expense_amount,
        income: income_amount,
        transfer: transfer_amount,
        net: income_amount - expense_amount,
        total_transactions: base_transactions.where(date: current_date).count
      }
      
      current_date = current_date.next_day
    end

    days
  end

  def group_by_year
    yearly_data = base_transactions
                   .group_by_year(:date, range: start_date..end_date)
                   .group(:transaction_type)
                   .sum(:amount)

    years = []
    current_year = start_date.beginning_of_year

    while current_year <= end_date.end_of_year
      year_key = current_year.year.to_s
      
      expense_amount = yearly_data[[current_year, 'expense']] || 0
      income_amount = yearly_data[[current_year, 'income']] || 0
      transfer_amount = yearly_data[[current_year, 'transfer']] || 0
      
      years << {
        period: year_key,
        date: current_year,
        expense: expense_amount,
        income: income_amount,
        transfer: transfer_amount,
        net: income_amount - expense_amount,
        total_transactions: base_transactions.where(
          date: current_year.beginning_of_year..current_year.end_of_year
        ).count
      }
      
      current_year = current_year.next_year
    end

    years
  end

  def calculate_variability_metrics
    trend_data = generate_trend_analysis
    expense_amounts = trend_data.map { |period| period[:expense] }
    income_amounts = trend_data.map { |period| period[:income] }
    net_amounts = trend_data.map { |period| period[:net] }

    {
      expense_variability: calculate_variability_stats(expense_amounts),
      income_variability: calculate_variability_stats(income_amounts),
      net_variability: calculate_variability_stats(net_amounts)
    }
  end

  def calculate_variability_stats(amounts)
    return {} if amounts.empty?

    mean = amounts.sum.to_f / amounts.size
    variance = amounts.sum { |amount| (amount - mean) ** 2 } / amounts.size
    std_deviation = Math.sqrt(variance)
    coefficient_of_variation = mean.zero? ? 0 : (std_deviation / mean.abs) * 100

    {
      mean: mean.round(2),
      median: amounts.sort[amounts.size / 2]&.round(2) || 0,
      std_deviation: std_deviation.round(2),
      coefficient_of_variation: coefficient_of_variation.round(2),
      min: amounts.min || 0,
      max: amounts.max || 0,
      range: (amounts.max || 0) - (amounts.min || 0)
    }
  end

  def generate_period_comparison
    current_period = generate_period_data(start_date, end_date)
    period_length = (end_date - start_date).to_i + 1
    previous_start = start_date - period_length.days
    previous_end = start_date - 1.day
    previous_period = generate_period_data(previous_start, previous_end)

    {
      current_period: current_period,
      previous_period: previous_period,
      comparison: {
        expense_change: calculate_percentage_change(previous_period[:total_expense], current_period[:total_expense]),
        income_change: calculate_percentage_change(previous_period[:total_income], current_period[:total_income]),
        transaction_count_change: calculate_percentage_change(previous_period[:transaction_count], current_period[:transaction_count])
      }
    }
  end

  def generate_period_data(start_date, end_date)
    period_transactions = Transaction.where(date: start_date..end_date)
    period_transactions = period_transactions.where(account_id: account_id) if account_id.present?
    period_transactions = period_transactions.where(category_id: category_id) if category_id.present?

    {
      total_expense: period_transactions.where(transaction_type: 'expense').sum(:amount),
      total_income: period_transactions.where(transaction_type: 'income').sum(:amount),
      transaction_count: period_transactions.count,
      average_transaction: period_transactions.average(:amount)&.round(2) || 0
    }
  end

  def calculate_percentage_change(old_value, new_value)
    return 0 if old_value.zero?
    ((new_value - old_value) / old_value.abs * 100).round(2)
  end

  def generate_category_breakdown
    return {} if category_id.present? # Não faz sentido quebrar por categoria se já estamos filtrando por uma

    base_transactions
      .joins(:category)
      .group('categories.name')
      .group(:transaction_type)
      .sum(:amount)
      .transform_keys { |key| { category: key[0], type: key[1] } }
  end

  def generate_predictions
    trend_data = generate_trend_analysis
    return {} if trend_data.size < 3

    expense_trend = calculate_trend(trend_data.map { |d| d[:expense] })
    income_trend = calculate_trend(trend_data.map { |d| d[:income] })

    next_period_date = case analysis_type
                      when 'daily'
                        end_date + 1.day
                      when 'weekly'
                        end_date + 1.week
                      when 'monthly'
                        end_date + 1.month
                      when 'yearly'
                        end_date + 1.year
                      end

    {
      next_period: {
        date: next_period_date,
        predicted_expense: expense_trend[:next_value]&.round(2) || 0,
        predicted_income: income_trend[:next_value]&.round(2) || 0,
        confidence: calculate_prediction_confidence(trend_data)
      },
      trend_direction: {
        expense: expense_trend[:direction],
        income: income_trend[:direction]
      }
    }
  end

  def calculate_trend(values)
    return { direction: 'stable', next_value: 0 } if values.size < 2

    # Cálculo simples de tendência linear
    n = values.size
    x_sum = (1..n).sum
    y_sum = values.sum
    xy_sum = values.each_with_index.sum { |y, i| y * (i + 1) }
    x2_sum = (1..n).sum { |x| x ** 2 }

    slope = (n * xy_sum - x_sum * y_sum).to_f / (n * x2_sum - x_sum ** 2)
    intercept = (y_sum - slope * x_sum).to_f / n

    next_x = n + 1
    next_value = slope * next_x + intercept

    direction = if slope > 0.01
                  'increasing'
                elsif slope < -0.01
                  'decreasing'
                else
                  'stable'
                end

    { direction: direction, next_value: next_value, slope: slope }
  end

  def calculate_prediction_confidence(trend_data)
    # Calcula confiança baseada na variabilidade dos dados
    amounts = trend_data.map { |d| d[:expense] + d[:income] }
    variability = calculate_variability_stats(amounts)
    
    # Menor coeficiente de variação = maior confiança
    cv = variability[:coefficient_of_variation] || 100
    confidence = [100 - cv, 0].max
    
    case confidence
    when 80..100
      'high'
    when 50..79
      'medium'
    else
      'low'
    end
  end

  def generate_recommendations
    recommendations = []
    variability = calculate_variability_metrics
    
    # Recomendações baseadas na variabilidade de gastos
    if variability[:expense_variability][:coefficient_of_variation].to_f > 50
      recommendations << {
        type: 'variability',
        priority: 'high',
        message: 'Seus gastos têm alta variabilidade. Considere criar um orçamento mais detalhado.',
        action: 'create_budget'
      }
    end

    # Recomendações baseadas na tendência
    predictions = generate_predictions
    if predictions.dig(:trend_direction, :expense) == 'increasing'
      recommendations << {
        type: 'trend',
        priority: 'medium',
        message: 'Seus gastos estão em tendência de crescimento. Revise suas despesas.',
        action: 'review_expenses'
      }
    end

    # Recomendações baseadas no período de comparação
    comparison = generate_period_comparison
    if comparison.dig(:comparison, :expense_change).to_f > 20
      recommendations << {
        type: 'period_comparison',
        priority: 'high',
        message: 'Seus gastos aumentaram significativamente em relação ao período anterior.',
        action: 'analyze_increase'
      }
    end

    recommendations
  end

  def end_date_after_start_date
    return unless start_date && end_date
    
    errors.add(:end_date, 'deve ser posterior à data de início') if end_date <= start_date
  end
end
