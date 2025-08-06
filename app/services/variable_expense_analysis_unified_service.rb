# Unified service for variable expense analysis
# Consolidates VariableExpenseAnalysisService and VariableExpenseAnalyzerService
class VariableExpenseAnalysisUnifiedService
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Attributes for flexible analysis
  attribute :user
  attribute :category_id, :integer
  attribute :account_id, :integer
  attribute :start_date, :date, default: -> { 6.months.ago }
  attribute :end_date, :date, default: -> { Date.current }
  attribute :analysis_type, :string, default: 'monthly'
  attribute :timeframe_months, :integer, default: 12

  validates :user, presence: true
  validates :start_date, :end_date, presence: true
  validates :analysis_type, inclusion: { in: %w[daily weekly monthly yearly] }
  validate :end_date_after_start_date

  def call
    return { success: false, errors: errors.full_messages } unless valid?

    {
      success: true,
      analysis_type: analysis_type,
      period: "#{start_date.strftime('%Y-%m-%d')} to #{end_date.strftime('%Y-%m-%d')}",
      summary: generate_summary,
      statistics: calculate_statistics,
      monthly_breakdown: monthly_breakdown,
      trends: calculate_trends,
      projections: calculate_projections,
      variability_metrics: calculate_variability_metrics,
      recommendations: generate_recommendations
    }
  rescue StandardError => e
    { success: false, errors: ["Analysis failed: #{e.message}"] }
  end

  # Class method for simple category analysis (public API convenience method)
  def self.analyze_category(category, timeframe_months: 12, analysis_date: Date.current)
    service = new(
      user: category.user,
      category_id: category.id,
      start_date: timeframe_months.months.ago(analysis_date),
      end_date: analysis_date,
      timeframe_months: timeframe_months
    )
    service.call
  end

  # Class method for projected expense calculation
  def self.projected_expense_for_category(category, months_ahead = 1, user = nil)
    service = new(
      user: user || category.user,
      category_id: category.id,
      start_date: 12.months.ago,
      end_date: Date.current
    )
    
    result = service.call
    return 0 unless result[:success]

    # Use trend data to project future expense
    trend = result[:trends][:overall_trend]
    avg_monthly = result[:statistics][:monthly_average]
    
    case trend
    when 'increasing'
      growth_factor = result[:trends][:growth_rate] || 0.05
      avg_monthly * (1 + growth_factor) * months_ahead
    when 'decreasing'
      decline_factor = result[:trends][:decline_rate] || 0.05
      avg_monthly * (1 - decline_factor) * months_ahead
    else
      avg_monthly * months_ahead
    end
  end

  private

  def base_transactions
    @base_transactions ||= begin
      scope = user.transactions.confirmed.where(event_date: start_date..end_date)
      scope = scope.where(category_id: category_id) if category_id.present?
      if account_id.present?
        # Filter transactions that have entries from the specified account
        scope = scope.joins(:entries).where(entries: { account_id: account_id, entry_type: 'credit' }).distinct
      end
      scope
    end
  end

  def generate_summary
    transactions = base_transactions
    
    {
      total_transactions: transactions.count,
      total_amount: transactions.sum(:amount),
      date_range: {
        start: start_date,
        end: end_date,
        days: FinancialConstants.safe_to_integer((end_date - start_date)) + 1
      },
      filters: {
        category: category_id ? Category.find(category_id).name : 'All categories',
        account: account_id ? Account.find(account_id).name : 'All accounts'
      }
    }
  end

  def calculate_statistics
    transactions = base_transactions
    amounts = transactions.pluck(:amount)
    
    return {} if amounts.empty?

    monthly_amounts = group_by_period(transactions, 'monthly').values
    
    {
      total_amount: amounts.sum,
      transaction_count: amounts.size,
      average_transaction: amounts.sum / amounts.size,
      monthly_average: monthly_amounts.empty? ? 0 : monthly_amounts.sum / monthly_amounts.size,
      min_transaction: amounts.min,
      max_transaction: amounts.max,
      median_transaction: calculate_median(amounts),
      standard_deviation: calculate_standard_deviation(amounts)
    }
  end

  def monthly_breakdown
    group_by_period(base_transactions, 'monthly')
  end

  def calculate_trends
    monthly_data = monthly_breakdown
    return {} if monthly_data.size < 2

    amounts = monthly_data.values
    trend_direction = calculate_trend_direction(amounts)
    
    {
      overall_trend: trend_direction,
      growth_rate: calculate_growth_rate(amounts),
      decline_rate: calculate_decline_rate(amounts),
      volatility: calculate_volatility(amounts),
      seasonal_patterns: detect_seasonal_patterns(monthly_data)
    }
  end

  def calculate_projections
    trends = calculate_trends
    stats = calculate_statistics
    
    return {} if trends.empty? || stats.empty?

    base_monthly = stats[:monthly_average]
    
    {
      next_month: project_next_period(base_monthly, trends, 1),
      next_quarter: project_next_period(base_monthly, trends, 3),
      next_year: project_next_period(base_monthly, trends, 12),
      confidence_level: calculate_confidence_level(stats, trends)
    }
  end

  def calculate_variability_metrics
    amounts = base_transactions.pluck(:amount)
    return {} if amounts.empty?

    mean = FinancialConstants.safe_to_float(amounts.sum) / amounts.size
    variance = amounts.map { |amount| (amount - mean) ** 2 }.sum / amounts.size
    
    {
      variance: variance,
      standard_deviation: Math.sqrt(variance),
      coefficient_of_variation: mean.zero? ? 0 : Math.sqrt(variance) / mean,
      variability_level: classify_variability(Math.sqrt(variance), mean)
    }
  end

  def generate_recommendations
    stats = calculate_statistics
    trends = calculate_trends
    variability = calculate_variability_metrics
    
    recommendations = []
    
    # High variability recommendation
    if variability[:variability_level] == 'high'
      recommendations << {
        type: 'budget_control',
        priority: 'high',
        message: 'Esta categoria tem alta variabilidade. Considere estabelecer um orçamento mais rígido.',
        action: 'Set monthly budget limit'
      }
    end

    # Increasing trend recommendation
    if trends[:overall_trend] == 'increasing'
      recommendations << {
        type: 'trend_alert',
        priority: 'medium',
        message: 'Gastos nesta categoria estão aumentando. Monitore de perto.',
        action: 'Review spending patterns'
      }
    end

    # Low activity recommendation
    if stats[:transaction_count] < 5
      recommendations << {
        type: 'data_quality',
        priority: 'low',
        message: 'Poucos dados para análise confiável. Continue coletando dados.',
        action: 'Continue tracking'
      }
    end

    recommendations
  end

  # Helper methods

  def end_date_after_start_date
    return unless start_date && end_date
    errors.add(:end_date, 'must be after start date') if end_date <= start_date
  end

  def group_by_period(transactions, period_type)
    case period_type
    when 'daily'
      transactions.group_by { |t| t.event_date }
                  .transform_values { |txs| txs.sum(&:amount) }
    when 'weekly'
      transactions.group_by { |t| t.event_date.beginning_of_week }
                  .transform_values { |txs| txs.sum(&:amount) }
    when 'monthly'
      transactions.group_by { |t| t.event_date.beginning_of_month }
                  .transform_values { |txs| txs.sum(&:amount) }
    when 'yearly'
      transactions.group_by { |t| t.event_date.beginning_of_year }
                  .transform_values { |txs| txs.sum(&:amount) }
    else
      {}
    end
  end

  def calculate_median(amounts)
    sorted = amounts.sort
    mid = sorted.length / 2
    sorted.length.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0
  end

  def calculate_standard_deviation(amounts)
    return 0 if amounts.size <= 1
    
    mean = FinancialConstants.safe_to_float(amounts.sum) / amounts.size
    variance = amounts.map { |amount| (amount - mean) ** 2 }.sum / (amounts.size - 1)
    Math.sqrt(variance)
  end

  def calculate_trend_direction(amounts)
    return 'stable' if amounts.size < 3
    
    first_half = amounts[0..amounts.size/2]
    second_half = amounts[amounts.size/2..-1]
    
    first_avg = first_half.sum / first_half.size
    second_avg = second_half.sum / second_half.size
    
    change_ratio = (second_avg - first_avg) / first_avg.abs if first_avg != 0
    
    if change_ratio.nil? || change_ratio.abs < 0.1
      'stable'
    elsif change_ratio > 0
      'increasing'
    else
      'decreasing'
    end
  end

  def calculate_growth_rate(amounts)
    return 0 if amounts.size < 2
    
    first = amounts.first
    last = amounts.last
    
    return 0 if first.zero?
    
    (last - first) / first.abs
  end

  def calculate_decline_rate(amounts)
    growth_rate = calculate_growth_rate(amounts)
    growth_rate < 0 ? growth_rate.abs : 0
  end

  def calculate_volatility(amounts)
    return 0 if amounts.size < 2
    
    mean = FinancialConstants.safe_to_float(amounts.sum) / amounts.size
    variance = amounts.map { |amount| (amount - mean) ** 2 }.sum / amounts.size
    Math.sqrt(variance) / mean
  end

  def detect_seasonal_patterns(monthly_data)
    # Simple seasonal pattern detection
    # More sophisticated analysis could be added here
    return {} if monthly_data.size < 12
    
    months = monthly_data.keys.map(&:month)
    amounts = monthly_data.values
    
    monthly_averages = amounts.each_with_index
                             .group_by { |_, i| months[i] }
                             .transform_values { |group| group.map(&:first).sum / group.size }
    
    {
      peak_month: monthly_averages.max_by(&:last)&.first,
      low_month: monthly_averages.min_by(&:last)&.first,
      monthly_averages: monthly_averages
    }
  end

  def project_next_period(base_amount, trends, months)
    case trends[:overall_trend]
    when 'increasing'
      base_amount * (1 + (trends[:growth_rate] || 0.05)) * months
    when 'decreasing'
      base_amount * (1 - (trends[:decline_rate] || 0.05)) * months
    else
      base_amount * months
    end
  end

  def calculate_confidence_level(stats, trends)
    # Simple confidence calculation based on data quality
    confidence = 0.5 # base confidence
    
    # More transactions = higher confidence
    confidence += [stats[:transaction_count] / 50.0, 0.3].min
    
    # Lower volatility = higher confidence
    volatility = trends[:volatility] || 1.0
    confidence += [(1 - volatility), 0.2].min
    
    # Cap at 100%
    [confidence, 1.0].min
  end

  def classify_variability(std_dev, mean)
    return 'low' if mean.zero?
    
    cv = std_dev / mean
    
    case cv
    when 0..0.3
      'low'
    when 0.3..0.7
      'medium'
    else
      'high'
    end
  end
end
