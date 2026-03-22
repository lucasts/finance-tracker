class RecurringCommitment < ApplicationRecord
  include FinancialConstants
  include AmountNormalization
  include PaidAmountCalculations

  # User association
  belongs_to :user

  # Existing associations
  belongs_to :category
  belongs_to :from_account, class_name: "Account"
  belongs_to :to_account, class_name: "Account"

  has_many :transactions, dependent: :restrict_with_error

  enum :status, { active: 0, paused: 1, closed: 2 }

  validates :name, :category_id, :recurrence_frequency, :start_date, :status, presence: true
  validates :from_account, presence: true
  validates :to_account, presence: true
  # Supported frequencies expanded to match product spec
  SUPPORTED_FREQUENCIES = %w[daily weekly fortnightly monthly bimonthly quarterly semiannual annual biennial].freeze
  validates :recurrence_frequency, inclusion: { in: SUPPORTED_FREQUENCIES }, allow_blank: true
  validates :default_amount, numericality: { greater_than: 0 }, allow_nil: true

  validate :accounts_must_be_different

  # Useful scopes
  scope :active_commitments, -> { where(status: :active) }
  scope :by_frequency, ->(freq) { where(recurrence_frequency: freq) }
  scope :monthly_commitments, -> { where(recurrence_frequency: "monthly") }
  scope :with_default_amount, -> { where.not(default_amount: nil) }

  # Commitments that are still in the active period
  scope :current_active, -> do
    where(status: :active)
      .where("start_date <= ?", Date.current)
      .where("end_date IS NULL OR end_date >= ?", Date.current)
  end

  # Next due date based on frequency
  # Next due date based on frequency - unified and consistent
  def next_occurrence_date(from_date = Date.current)
    return nil if closed? || (end_date && from_date > end_date)

    calculate_next_date_from(from_date)
  end

  # Check if it's active in the period
  def active_on?(date = Date.current)
    active? &&
      date >= start_date &&
      (end_date.nil? || date <= end_date)
  end

  # Average value of associated transactions
  def average_amount
    return default_amount if transactions.empty? && default_amount.present?

    confirmed_transactions = transactions.where(status: "confirmed")
    return 0 if confirmed_transactions.empty?

    confirmed_transactions.average(:amount)&.round(2) || 0
  end

  # Total amount spent on this commitment
  def total_spent
    confirmed_transactions = transactions.where(status: "confirmed")
    confirmed_transactions.sum(:amount)&.round(2) || 0
  end

  # Last recorded transaction
  def last_transaction
    transactions.order(:payment_date).last
  end

  # Next expected transaction (if any)
  def next_expected_transaction
    transactions.where("payment_date > ?", Date.current).order(:payment_date).first
  end

  # Summary status of the commitment
  def summary_status
    return "expired" if end_date && end_date < Date.current
    return "inactive" unless active?
    return "not_started" if start_date > Date.current

    last_tx = last_transaction
    if last_tx
      next_due = next_occurrence_date(last_tx.payment_date)
      return "overdue" if next_due && next_due < Date.current
    end

    "active"
  end

  # Get analysis for this commitment's spending pattern
  def expense_analysis(timeframe_months: 12)
    return nil unless category.present?

    VariableExpenseAnalysisUnifiedService.analyze_category(
      category,
      timeframe_months: timeframe_months
    )
  end

  # Check if this commitment generates variable expenses that should be analyzed
  def generates_variable_expenses?
    FinancialConstants.variable_expense?(name) ||
      FinancialConstants.variable_expense?(category.name)
  end

  # Expected value for matching imported transactions
  def expected_amount
    default_amount
  end

  # Documentation:
  # - The default value can be overridden by each transaction (variable recurring)
  # - The system generates transactions periodically according to frequency and status

  private

  # Unified date calculation method for consistency
  def calculate_next_date_from(from_date)
    freq = (respond_to?(:frequency) ? frequency : recurrence_frequency).to_s
    case freq
    when "daily"
      from_date + 1.day
    when "weekly"
  from_date.next_week(:monday)
    when "fortnightly"
      from_date + 14.days
    when "monthly"
      from_date + 1.month
    when "bimonthly"
      from_date + 2.months
    when "quarterly"
      from_date + 3.months
    when "semiannual"
      from_date + 6.months
    when "annual", "yearly"
      from_date + 1.year
    when "biennial"
      from_date + 2.years
    else
      # Fallback: monthly to avoid silent infinite loops
      from_date + 1.month
    end
  end

  def accounts_must_be_different
    if from_account_id == to_account_id
      errors.add(:to_account_id, "não pode ser igual à conta de origem")
    end
  end
end
