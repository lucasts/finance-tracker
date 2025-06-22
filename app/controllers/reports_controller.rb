class ReportsController < ApplicationController
  def index
    @selected_month = params[:month] || Date.current.strftime("%Y-%m")
    @start_date = Date.parse("#{@selected_month}-01")
    @end_date = @start_date.end_of_month
    
    # Month navigation
    @prev_month = @start_date.prev_month.strftime("%Y-%m")
    @next_month = @start_date.next_month.strftime("%Y-%m")
    @selected_month_long = I18n.l(@start_date, format: "%B de %Y")
    
    # Load reports data
    load_transactions_data
    load_category_analysis
    load_credit_card_analysis
    load_monthly_trends
    load_savings_analysis

    # Projection of recurring commitments for the month
    projection_service = RecurringProjectionService.new(as_of: @start_date)
    @projected_transactions = projection_service.projected_transactions
    @projected_expense_total = @projected_transactions.select { |t| t[:amount].to_f < 0 }.sum { |t| t[:amount].to_f.abs }
    @projected_income_total = @projected_transactions.select { |t| t[:amount].to_f > 0 }.sum { |t| t[:amount].to_f }
    @projected_balance = @balance + @projected_income_total - @projected_expense_total
  end

  private

  def load_transactions_data
    # Base query for selected month
    @transactions = Transaction.where(event_date: @start_date..@end_date)
    
    # Income and expense totals using transaction_type
    @income_total = @transactions.where(transaction_type: "income").sum(:amount)
    @expense_total = @transactions.where(transaction_type: "expense").sum(:amount)
    @transfer_total = @transactions.where(transaction_type: "transfer").sum(:amount)
    @balance = @income_total - @expense_total
    
    # Transaction counts
    @income_count = @transactions.where(transaction_type: "income").count
    @expense_count = @transactions.where(transaction_type: "expense").count
    @transfer_count = @transactions.where(transaction_type: "transfer").count
    @total_transactions = @transactions.count
  end

  def load_category_analysis
    # Category spending breakdown (only expenses)
    @category_breakdown = @transactions
      .joins(:category)
      .where(transaction_type: "expense")
      .group('categories.name')
      .sum(:amount)
      .sort_by { |_category, amount| -amount }
      .first(10)

    # Calculate percentages
    if @expense_total > 0
      @category_percentages = @category_breakdown.map do |category, amount|
        [category, amount, (amount / @expense_total * 100).round(1)]
      end
    else
      @category_percentages = []
    end
    
    # Initialize @categories_analysis for the view
    @categories_analysis = @category_breakdown.to_h
  end

  def load_credit_card_analysis
    # Credit card statements for the month (using month string format YYYY-MM)
    selected_month = @start_date.strftime("%Y-%m")
    @credit_statements = CreditStatement.where(month: selected_month).includes(:transactions)

    # Credit card spending summary
    @cc_total_due = @credit_statements.sum(:amount_due)
    @cc_total_paid = @credit_statements.sum(:amount_paid)
    @cc_pending = @cc_total_due - @cc_total_paid

    # Status breakdown
    @cc_status_breakdown = @credit_statements.group(:status).count
  end

  def load_monthly_trends
    # Last 6 months data for trends
    @trend_months = 6.downto(1).map { |i| @start_date.months_ago(i) } + [@start_date]
    
    @monthly_trends = @trend_months.map do |month|
      month_start = month.beginning_of_month
      month_end = month.end_of_month
      
      month_transactions = Transaction.where(event_date: month_start..month_end)
      income = month_transactions.where(transaction_type: "income").sum(:amount)
      expenses = month_transactions.where(transaction_type: "expense").sum(:amount)
      
      {
        month: month,
        month_label: I18n.l(month, format: "%b/%Y"),
        income: income,
        expenses: expenses,
        balance: income - expenses,
        savings_rate: income > 0 ? ((income - expenses) / income * 100).round(1) : 0
      }
    end
  end

  def load_savings_analysis
    # Current month savings rate
    if @income_total > 0
      @savings_rate = ((@income_total - @expense_total) / @income_total * 100).round(1)
    else
      @savings_rate = 0
    end

    # Average savings rate over last 6 months
    avg_income = @monthly_trends.sum { |m| m[:income] } / @monthly_trends.size
    avg_expenses = @monthly_trends.sum { |m| m[:expenses] } / @monthly_trends.size
    
    if avg_income > 0
      @avg_savings_rate = ((avg_income - avg_expenses) / avg_income * 100).round(1)
    else
      @avg_savings_rate = 0
    end

    # Identify best and worst months
    @best_month = @monthly_trends.max_by { |m| m[:savings_rate] }
    @worst_month = @monthly_trends.min_by { |m| m[:savings_rate] }
  end
  
  def variable_expenses_analysis
    @account_id = params[:account_id]
    @category_id = params[:category_id]
    @start_date = params[:start_date]&.to_date || 6.months.ago
    @end_date = params[:end_date]&.to_date || Date.current
    @analysis_type = params[:analysis_type] || 'monthly'
    
    @analysis_result = VariableExpenseAnalyzerService.new(
      account_id: @account_id,
      category_id: @category_id,
      start_date: @start_date,
      end_date: @end_date,
      analysis_type: @analysis_type
    ).call
    
    @accounts = Account.all
    @categories = Category.all
    
    if @analysis_result[:success]
      @analysis_data = @analysis_result[:data]
    else
      flash.now[:alert] = @analysis_result[:errors].join(', ')
      @analysis_data = {}
    end
    
    respond_to do |format|
      format.html
      format.json { render json: @analysis_result }
    end
  end
end
