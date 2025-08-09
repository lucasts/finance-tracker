# frozen_string_literal: true

# CategoryProjectionCalculator
# Computes per-category expense projection in batch to avoid N+1 queries.
class CategoryProjectionCalculator
  DEFAULT_MONTHS_WINDOW = 3

  def self.call(user:, month_date:, months_window: DEFAULT_MONTHS_WINDOW)
    new(user: user, month_date: month_date, months_window: months_window).projections
  end

  def initialize(user:, month_date:, months_window: DEFAULT_MONTHS_WINDOW)
    @user = user
    @month_date = month_date.beginning_of_month
    @months_window = months_window
    @window_start = (@month_date - (months_window - 1).months).beginning_of_month
    @window_end = @month_date.end_of_month
  end

  def projections
    categories = @user.categories.where(category_type: :expense)
    return [] if categories.empty?

    current_spent_by_cat = expense_scope(@month_date.beginning_of_month, @month_date.end_of_month)
                           .group(:category_id).sum(:amount)

    window_totals = expense_scope(@window_start, @window_end)
                    .group(:category_id).sum(:amount)

    months_count = @months_window.nonzero? || 1

    categories.map do |cat|
      current_spent = FinancialConstants.safe_to_float(current_spent_by_cat[cat.id], 0)
      total_window = FinancialConstants.safe_to_float(window_totals[cat.id], 0)
      projected = (total_window / months_count).round(2)
      next if projected <= 0
      remaining = (projected - current_spent).round(2)
      percentage_used = projected.positive? ? FinancialConstants.calculate_percentage(current_spent, projected) : 0
      {
        category: cat,
        current_spent: current_spent,
        projected: projected,
        remaining: remaining,
        percentage_used: percentage_used
      }
    end.compact.sort_by { |h| -h[:projected] }
  end

  private

  def expense_scope(start_d, end_d)
    @user.transactions.expense.confirmed.where(event_date: start_d..end_d)
  end
end
