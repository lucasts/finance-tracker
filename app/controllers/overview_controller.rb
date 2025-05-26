class OverviewController < ApplicationController
  def index
    @period = params[:period] || Date.today.strftime("%Y-%m")
    @transactions = Transaction.where(period: @period)
    @income_total = @transactions.where(transaction_type: "income").sum(:amount)
    @expense_total = @transactions.where(transaction_type: "expense").sum(:amount)
    @balance = @income_total - @expense_total

    @category_totals = @transactions.joins(:category).group("categories.name").sum(:amount)

    current = Date.strptime(@period, "%Y-%m")
    @prev_period = (current << 1).strftime("%Y-%m")
    @next_period = (current >> 1).strftime("%Y-%m")
  end
end