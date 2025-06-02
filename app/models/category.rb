class Category < ApplicationRecord
  has_many :transactions, dependent: :restrict_with_error

  validates :name, presence: true

  # Get variable expense analysis for this category
  def expense_analysis(timeframe_months: 12, analysis_date: Date.current)
    VariableExpenseAnalysisService.new(
      self, 
      timeframe_months: timeframe_months, 
      analysis_date: analysis_date
    ).call
  end

  # Check if this category typically has variable expenses
  def variable_expense_category?
    variable_keywords = ['supermercado', 'mercado', 'farmácia', 'gasolina', 'combustível', 'consulta', 'médico', 'restaurante']
    variable_keywords.any? { |keyword| name.downcase.include?(keyword) }
  end

  # Get monthly averages for this category
  def monthly_average(months_back: 6)
    start_date = months_back.months.ago.beginning_of_month
    
    monthly_totals = transactions
                    .single_transactions
                    .confirmed
                    .where(event_date: start_date..Date.current)
                    .group_by { |t| t.event_date.beginning_of_month }
                    .map { |month, txns| txns.sum(&:amount) }
    
    return 0 if monthly_totals.empty?
    
    monthly_totals.sum / monthly_totals.length
  end
end
