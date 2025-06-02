class VariableExpenseAnalysisService
  attr_reader :category, :timeframe_months, :analysis_date
  
  def initialize(category, timeframe_months: 12, analysis_date: Date.current)
    @category = category
    @timeframe_months = timeframe_months
    @analysis_date = analysis_date
  end
  
  def call
    {
      category: category.name,
      timeframe: "#{timeframe_months} months",
      analysis_date: analysis_date,
      statistics: calculate_statistics,
      monthly_breakdown: monthly_breakdown,
      trends: calculate_trends,
      projections: calculate_projections,
      recommendations: generate_recommendations
    }
  end
  
  private
  
  def variable_transactions
    @variable_transactions ||= category.transactions
                                      .single_transactions # Only single transactions for variable expenses
                                      .expense
                                      .confirmed
                                      .where(event_date: analysis_date - timeframe_months.months..analysis_date)
                                      .order(:event_date)
  end
  
  def calculate_statistics
    amounts = variable_transactions.pluck(:amount)
    return zero_statistics if amounts.empty?
    
    {
      total_transactions: amounts.count,
      total_amount: amounts.sum,
      average_amount: amounts.sum / amounts.count,
      median_amount: median(amounts),
      min_amount: amounts.min,
      max_amount: amounts.max,
      standard_deviation: standard_deviation(amounts),
      coefficient_of_variation: coefficient_of_variation(amounts)
    }
  end
  
  def monthly_breakdown
    breakdown = {}
    
    (0...timeframe_months).each do |i|
      month_date = (analysis_date - i.months).beginning_of_month
      month_key = month_date.strftime('%Y-%m')
      
      month_transactions = variable_transactions.where(
        event_date: month_date..month_date.end_of_month
      )
      
      breakdown[month_key] = {
        date: month_date,
        transaction_count: month_transactions.count,
        total_amount: month_transactions.sum(:amount),
        average_amount: month_transactions.count > 0 ? month_transactions.sum(:amount) / month_transactions.count : 0,
        transactions: month_transactions.pluck(:description, :amount, :event_date)
      }
    end
    
    breakdown.sort.to_h
  end
  
  def calculate_trends
    monthly_totals = monthly_breakdown.values.map { |month| month[:total_amount] }
    return {} if monthly_totals.length < 2
    
    # Simple linear regression for trend analysis
    x_values = (0...monthly_totals.length).to_a
    y_values = monthly_totals
    
    slope = linear_regression_slope(x_values, y_values)
    
    {
      trend_direction: slope > 0 ? 'increasing' : 'decreasing',
      monthly_change_rate: slope,
      trend_strength: correlation_coefficient(x_values, y_values).abs,
      is_stable: standard_deviation(monthly_totals) < (monthly_totals.sum / monthly_totals.length) * 0.3
    }
  end
  
  def calculate_projections
    stats = calculate_statistics
    trends = calculate_trends
    
    # Base projection on recent 3-month average with trend adjustment
    recent_months = monthly_breakdown.values.last(3)
    recent_average = recent_months.sum { |m| m[:total_amount] } / recent_months.length
    
    # Apply trend for future projections
    trend_adjustment = trends[:monthly_change_rate] || 0
    
    {
      next_month_estimate: recent_average + trend_adjustment,
      next_quarter_estimate: (recent_average + trend_adjustment) * 3,
      confidence_level: calculate_confidence_level(stats, trends),
      methodology: "Based on #{recent_months.length}-month average with trend adjustment"
    }
  end
  
  def generate_recommendations
    stats = calculate_statistics
    trends = calculate_trends
    recommendations = []
    
    # High variability warning
    if stats[:coefficient_of_variation] && stats[:coefficient_of_variation] > 0.5
      recommendations << {
        type: 'high_variability',
        message: 'This category shows high spending variability. Consider setting monthly budgets.',
        priority: 'medium'
      }
    end
    
    # Increasing trend warning
    if trends[:trend_direction] == 'increasing' && trends[:trend_strength] > 0.6
      recommendations << {
        type: 'increasing_trend',
        message: 'Spending in this category is consistently increasing. Review recent purchases.',
        priority: 'high'
      }
    end
    
    # Unusual spending detection
    recent_amount = monthly_breakdown.values.last[:total_amount]
    if recent_amount > stats[:average_amount] * 1.5
      recommendations << {
        type: 'unusual_spending',
        message: 'Recent spending is significantly above average for this category.',
        priority: 'high'
      }
    end
    
    # Stability achievement
    if trends[:is_stable] && stats[:total_transactions] > 6
      recommendations << {
        type: 'stable_pattern',
        message: 'Spending in this category is stable and predictable.',
        priority: 'low'
      }
    end
    
    recommendations
  end
  
  def calculate_confidence_level(stats, trends)
    # Simple confidence calculation based on data points and stability
    base_confidence = [stats[:total_transactions] * 5, 100].min
    
    # Reduce confidence for high variability
    if stats[:coefficient_of_variation] && stats[:coefficient_of_variation] > 0.3
      base_confidence *= 0.8
    end
    
    # Increase confidence for stable trends
    if trends[:is_stable]
      base_confidence *= 1.1
    end
    
    [base_confidence.round, 100].min
  end
  
  # Utility methods for statistical calculations
  def median(array)
    sorted = array.sort
    len = sorted.length
    (sorted[(len - 1) / 2] + sorted[len / 2]) / 2.0
  end
  
  def standard_deviation(array)
    return 0 if array.length < 2
    
    mean = array.sum / array.length.to_f
    variance = array.sum { |x| (x - mean) ** 2 } / array.length.to_f
    Math.sqrt(variance)
  end
  
  def coefficient_of_variation(array)
    return 0 if array.empty?
    
    mean = array.sum / array.length.to_f
    return 0 if mean == 0
    
    standard_deviation(array) / mean
  end
  
  def linear_regression_slope(x_values, y_values)
    return 0 if x_values.length != y_values.length || x_values.length < 2
    
    n = x_values.length
    sum_x = x_values.sum
    sum_y = y_values.sum
    sum_xy = x_values.zip(y_values).sum { |x, y| x * y }
    sum_x_squared = x_values.sum { |x| x * x }
    
    (n * sum_xy - sum_x * sum_y).to_f / (n * sum_x_squared - sum_x * sum_x)
  end
  
  def correlation_coefficient(x_values, y_values)
    return 0 if x_values.length != y_values.length || x_values.length < 2
    
    n = x_values.length
    sum_x = x_values.sum
    sum_y = y_values.sum
    sum_xy = x_values.zip(y_values).sum { |x, y| x * y }
    sum_x_squared = x_values.sum { |x| x * x }
    sum_y_squared = y_values.sum { |y| y * y }
    
    numerator = n * sum_xy - sum_x * sum_y
    denominator = Math.sqrt((n * sum_x_squared - sum_x * sum_x) * (n * sum_y_squared - sum_y * sum_y))
    
    return 0 if denominator == 0
    
    numerator / denominator
  end
  
  def zero_statistics
    {
      total_transactions: 0,
      total_amount: 0,
      average_amount: 0,
      median_amount: 0,
      min_amount: 0,
      max_amount: 0,
      standard_deviation: 0,
      coefficient_of_variation: 0
    }
  end
end
