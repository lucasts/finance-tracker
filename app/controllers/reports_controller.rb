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
  end

  private

  def load_transactions_data
    # Base query for selected month
    @transactions = Transaction.where(transaction_date: @start_date..@end_date)
    
    # Income and expense totals
    @income_total = @transactions.where(amount: 0..).sum(:amount)
    @expense_total = @transactions.where(amount: ...0).sum(:amount).abs
    @balance = @income_total - @expense_total
    
    # Transaction counts
    @income_count = @transactions.where(amount: 0..).count
    @expense_count = @transactions.where(amount: ...0).count
    @total_transactions = @transactions.count
  end

  def load_category_analysis
    # Category spending breakdown (only expenses)
    @category_breakdown = @transactions
      .joins(:category)
      .where(amount: ...0)
      .group('categories.name')
      .sum(:amount)
      .transform_values(&:abs)
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
  end

  def load_credit_card_analysis
    # Credit card statements for the month
    @credit_statements = CreditStatement.where(
      period_start: @start_date..@end_date
    ).or(
      CreditStatement.where(period_end: @start_date..@end_date)
    ).includes(:transactions)

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
      
      month_transactions = Transaction.where(transaction_date: month_start..month_end)
      income = month_transactions.where(amount: 0..).sum(:amount)
      expenses = month_transactions.where(amount: ...0).sum(:amount).abs
      
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
end
