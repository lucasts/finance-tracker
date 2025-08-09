# frozen_string_literal: true

# MonthlyBalanceProjectionService
# Calcula visão dupla (competência vs caixa) para um mês dado e uma data de referência (as_of).
# Saída inclui bases realizadas e componentes futuros (recorrentes + parcelas + pendentes) para projeção.
class MonthlyBalanceProjectionService
  def self.call(user:, month_date:, as_of: Date.today)
    new(user: user, month_date: month_date, as_of: as_of).call
  end

  def initialize(user:, month_date:, as_of: Date.today)
    @user = user
    @month_date = month_date.beginning_of_month
    @as_of = as_of
    @month_end = @month_date.end_of_month
  end

  def call
    {
      competence: competence_projection,
      cash: cash_projection
    }
  end

  private

  def base_scope
    @user.transactions.where(event_date: @month_date..@month_end)
  end

  def payment_scope
    @user.transactions.where(payment_date: @month_date..@month_end)
  end

  def competence_projection
    income_base = base_scope.income.where('event_date <= ?', @as_of).sum(:amount)
    expense_base = base_scope.expense.where('event_date <= ?', @as_of).sum(:amount)

    future_income_tx = base_scope.income.where('event_date > ?', @as_of)
    future_expense_tx = base_scope.expense.where('event_date > ?', @as_of)

    projected_recurring = projected_recurring_expenses
    projected_installments = projected_installment_expenses

    future_income = future_income_tx.sum(:amount)
  future_expense = future_expense_tx.sum(:amount) + projected_recurring + projected_installments

    projected_balance = (income_base - expense_base) + future_income - future_expense

    {
      base_income: income_base,
      base_expense: expense_base,
      future_income: future_income,
  future_expense: future_expense,
      projected_recurring_expense: projected_recurring,
      projected_installment_expense: projected_installments,
      projected_balance: projected_balance
    }
  end

  def cash_projection
    income_base = payment_scope.income.where('payment_date <= ?', @as_of).sum(:amount)
    expense_base = payment_scope.expense.where('payment_date <= ?', @as_of).sum(:amount)

    future_income_tx = payment_scope.income.where('payment_date > ?', @as_of)
    future_expense_tx = payment_scope.expense.where('payment_date > ?', @as_of)

    projected_recurring = projected_recurring_expenses
    projected_installments = projected_installment_expenses

    future_income = future_income_tx.sum(:amount)
  future_expense = future_expense_tx.sum(:amount) + projected_recurring + projected_installments

    projected_balance = (income_base - expense_base) + future_income - future_expense

    {
      base_income: income_base,
      base_expense: expense_base,
      future_income: future_income,
  future_expense: future_expense,
      projected_recurring_expense: projected_recurring,
      projected_installment_expense: projected_installments,
      projected_balance: projected_balance
    }
  end

  def projected_recurring_expenses
  RecurringProjectionService.call(as_of: @as_of)
      .select { |p| p[:date] >= @as_of && p[:date] <= @month_end }
      .sum { |p| p[:amount].to_f.abs }
  end

  def projected_installment_expenses
    InstallmentProjectionService.call(as_of: @as_of, months_ahead: 0)
      .select { |p| p[:date] >= @as_of && p[:date] <= @month_end }
      .sum { |p| p[:amount].to_f.abs }
  end
end
