# frozen_string_literal: true

# Centralized service for installment date calculations
# Eliminates duplicated logic across controllers and jobs
class InstallmentDateCalculatorService
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Supported recurrence frequencies
  FREQUENCIES = %w[daily weekly monthly quarterly yearly].freeze

  attribute :start_date, :date
  attribute :recurrence_frequency, :string, default: "monthly"
  attribute :installment_number, :integer

  validates :start_date, presence: true
  validates :recurrence_frequency, inclusion: { in: FREQUENCIES }
  validates :installment_number, presence: true, numericality: { greater_than: 0 }

  def self.calculate_date(start_date, installment_number, frequency = "monthly")
    calculator = new(
      start_date: start_date,
      installment_number: installment_number,
      recurrence_frequency: frequency
    )
    calculator.calculate_date
  end

  def self.calculate_all_dates(start_date, total_installments, frequency = "monthly")
    (1..total_installments).map do |number|
      calculate_date(start_date, number, frequency)
    end
  end

  def self.calculate_due_dates_for_plan(installment_plan)
    calculate_all_dates(
      installment_plan.starts_on,
      installment_plan.installment_count,
      installment_plan.recurrence_frequency
    )
  end

  def calculate_date
    return nil unless valid?

    # Base calculation: start_date + (installment_number - 1) * period
    periods_to_add = installment_number - 1

    case recurrence_frequency
    when "daily"
      start_date + periods_to_add.days
    when "weekly"
      start_date + periods_to_add.weeks
    when "monthly"
      start_date + periods_to_add.months
    when "quarterly"
      start_date + (periods_to_add * 3).months
    when "yearly"
      start_date + periods_to_add.years
    else
      # Default to monthly for unknown frequencies
      start_date + periods_to_add.months
    end
  end

  def calculate_date_with_business_day_adjustment
    calculated_date = calculate_date
    return nil unless calculated_date

    # Adjust for weekends (move to next business day)
    while calculated_date.saturday? || calculated_date.sunday?
      calculated_date += 1.day
    end

    calculated_date
  end

  def next_installment_date
    return nil unless valid?

    self.installment_number += 1
    calculate_date
  end

  def previous_installment_date
    return nil unless valid? || installment_number <= 1

    self.installment_number -= 1
    calculate_date
  end

  # Calculate the period between installments
  def period_between_installments
    case recurrence_frequency
    when "daily" then 1.day
    when "weekly" then 1.week
    when "monthly" then 1.month
    when "quarterly" then 3.months
    when "yearly" then 1.year
    else 1.month
    end
  end

  # Check if a given date matches an installment schedule
  def self.matches_installment_schedule?(date, start_date, frequency)
    return false unless date >= start_date

    case frequency
    when "daily"
      true # Any date after start_date is valid for daily frequency
    when "weekly"
      date.wday == start_date.wday
    when "monthly"
      # Check if it's the same day of month (with adjustment for month-end)
      target_day = start_date.day
      date.day == target_day || (date == date.end_of_month && target_day > date.end_of_month.day)
    when "quarterly"
      # Same logic as monthly but check if months align with quarterly pattern
      months_diff = (date.year - start_date.year) * 12 + date.month - start_date.month
      months_diff % 3 == 0 && matches_day_of_month?(date, start_date)
    when "yearly"
      date.month == start_date.month && matches_day_of_month?(date, start_date)
    else
      false
    end
  end

  # Helper method to find the installment number for a given date
  def self.installment_number_for_date(target_date, start_date, frequency)
    return nil if target_date < start_date

    case frequency
    when "daily"
      FinancialConstants.safe_to_integer(target_date - start_date) + 1
    when "weekly"
      FinancialConstants.safe_to_integer((target_date - start_date) / 7) + 1
    when "monthly"
      months_diff = (target_date.year - start_date.year) * 12 + target_date.month - start_date.month
      months_diff + 1
    when "quarterly"
      months_diff = (target_date.year - start_date.year) * 12 + target_date.month - start_date.month
      (months_diff / 3) + 1
    when "yearly"
      target_date.year - start_date.year + 1
    else
      1
    end
  end

  private

  def self.matches_day_of_month?(date, start_date)
    target_day = start_date.day
    date.day == target_day || (date == date.end_of_month && target_day > date.end_of_month.day)
  end
end
