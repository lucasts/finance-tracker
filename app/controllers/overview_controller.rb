class OverviewController < ApplicationController
  def index
    @month = params[:month] || Date.today.strftime('%Y-%m')
    @transactions = Transaction.in_competence_month(@month)
    @income_total = Transaction.in_competence_month(@month).income.sum(:amount)
    @expense_total = Transaction.in_competence_month(@month).expense.sum(:amount)

    @balance = @income_total - @expense_total

    @category_totals = @transactions.joins(:category).group("categories.name").sum(:amount)

    current = Date.strptime(@month, "%Y-%m")
    @prev_month = (current << 1).strftime("%Y-%m")
    @next_month = (current >> 1).strftime("%Y-%m")
  end
end