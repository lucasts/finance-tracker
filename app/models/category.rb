class Category < ApplicationRecord
  # User association
  belongs_to :user
  
  # Enum para tipo de categoria
  enum :category_type, { income: 0, expense: 1 }, default: :expense
  
  # Existing associations
  has_many :transactions, dependent: :restrict_with_error

  validates :name, presence: true, length: { maximum: 255 }, uniqueness: { scope: :user_id }
  validates :category_type, presence: true
  validates :description, length: { maximum: 500 }, allow_blank: true

  # Get variable expense analysis for this category
  def expense_analysis(timeframe_months: 12, analysis_date: Date.current)
    VariableExpenseAnalysisUnifiedService.analyze_category(
      self, 
      timeframe_months: timeframe_months, 
      analysis_date: analysis_date
    )
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

  # Automatic expense projection for this category
  def projected_expense(months_ahead = 1, user = nil)
    VariableExpenseAnalysisUnifiedService.projected_expense_for_category(self, months_ahead, user || self.user)
  end
end
