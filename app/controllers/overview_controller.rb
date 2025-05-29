class OverviewController < ApplicationController
  def index
    @month = params[:month] || Date.today.strftime('%Y-%m')
    @transactions = Transaction.in_competence_month(@month)
    @income_total = Transaction.in_competence_month(@month).income.sum(:amount)
    @expense_total = Transaction.in_competence_month(@month).expense.sum(:amount)

    @balance = @income_total - @expense_total

    @category_totals = @transactions.joins(:category).group("categories.name").sum(:amount)

    current_date = Date.strptime(@month, "%Y-%m")
    @prev_month = (current_date << 1).strftime("%Y-%m")
    @next_month = (current_date >> 1).strftime("%Y-%m")
    @selected_month_long = I18n.l(current_date, format: "%B de %Y")

    # Busca a conta de cartão de crédito
    @credit_card_account = Account.find_by(account_type: AccountType.find_by(code: "CREDIT"))
    # Busca a fatura do mês
    @credit_statement = CreditStatement.find_by(account: @credit_card_account, month: @month)

    @statement_due = @credit_statement&.due_on
    @statement_month_label = current_date.strftime("%B")

    @upcoming = Transaction.pending.in_payment_month(@month).limit(5)
    @category_ranking = category_ranking @month
    @projected_balance = projected_balance @balance, @month
    @balance_alert = balance_alert @projected_balance
    today = Date.today
    @month_end = Date.new(today.year, today.month, -1)
  end
end

def category_ranking(month = nil)
  month ||= Date.today.strftime('%Y-%m')
  Transaction
    .expense
    .in_competence_month(month)
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