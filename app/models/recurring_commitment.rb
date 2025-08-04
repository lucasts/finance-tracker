class RecurringCommitment < ApplicationRecord
  include FinancialConstants
  include AmountNormalization
  include PaidAmountCalculations
  
  # User association
  belongs_to :user
  
  # Existing associations
  belongs_to :category
  belongs_to :from_account, class_name: 'Account'
  belongs_to :to_account, class_name: 'Account'
  
  has_many :transactions, dependent: :restrict_with_error
  
  enum :status, { active: 0, paused: 1, closed: 2 }

  validates :name, :category_id, :recurrence_frequency, :start_date, :status, presence: true
  validates :from_account, presence: true
  validates :to_account, presence: true
  validates :recurrence_frequency, inclusion: { in: %w[monthly weekly annual] }, allow_blank: true
  validates :default_amount, numericality: { greater_than: 0 }, allow_nil: true

  validate :accounts_must_be_different

  # Useful scopes
  scope :active_commitments, -> { where(status: :active) }
  scope :by_frequency, ->(freq) { where(recurrence_frequency: freq) }
  scope :monthly_commitments, -> { where(recurrence_frequency: 'monthly') }
  scope :with_default_amount, -> { where.not(default_amount: nil) }

  # Commitments that are still in the active period
  scope :current_active, -> do
    where(status: :active)
      .where('start_date <= ?', Date.current)
      .where('end_date IS NULL OR end_date >= ?', Date.current)
  end

  # Next due date based on frequency
  # Next due date based on frequency - unified and consistent
  def next_occurrence_date(from_date = Date.current)
    return nil if closed? || (end_date && from_date > end_date)

    calculate_next_date_from(from_date)
  end
  
  # Alias for backward compatibility and naming consistency
  alias_method :next_due_date, :next_occurrence_date
  alias_method :next_occurrence_after, :next_occurrence_date

  # Check if it's active in the period
  def active_on?(date = Date.current)
    active? &&
      date >= start_date &&
      (end_date.nil? || date <= end_date)
  end

  # Average value of associated transactions
  def average_amount
    return default_amount if transactions.empty? && default_amount.present?

    confirmed_transactions = transactions.where(status: 'confirmed')
    return 0 if confirmed_transactions.empty?

    confirmed_transactions.average(:amount)&.round(2) || 0
  end

  # Alias for backward compatibility
  alias_method :total_spent, :amount_paid

  # Last recorded transaction
  def last_transaction
    transactions.order(:payment_date).last
  end

  # Next expected transaction (if any)
  def next_expected_transaction
    transactions.where('payment_date > ?', Date.current).order(:payment_date).first
  end

  # Summary status of the commitment
  def summary_status
    return 'expired' if end_date && end_date < Date.current
    return 'inactive' unless active?
    return 'not_started' if start_date > Date.current

    last_tx = last_transaction
    if last_tx
      next_due = next_occurrence_date(last_tx.payment_date)
      return 'overdue' if next_due && next_due < Date.current
    end

    'active'
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

  # Indicates if the commitment has a fixed value (for compatibility with jobs/specs)
  def fixed_amount?
    true
  end

  # Expected value for compatibility with jobs/specs
  def expected_amount
    default_amount
  end

  # Documentation:
  # - The default value can be overridden by each transaction (variable recurring)
  # - The system generates transactions periodically according to frequency and status

  private

  # Unified date calculation method for consistency
  def calculate_next_date_from(from_date)
    # Use frequency attribute if available, fallback to recurrence_frequency
    freq = respond_to?(:frequency) ? frequency : recurrence_frequency
    
    case freq
    when 'weekly'
      # For weekly frequency, go to the next week (Monday to Monday)
      from_date.next_week
    when 'monthly'
      from_date + 1.month
    when 'quarterly'
      from_date + 3.months
    when 'yearly', 'annual'
      from_date + 1.year
    else
      from_date + 1.month # default to monthly
    end
  end

  def accounts_must_be_different
    if from_account_id == to_account_id
      errors.add(:to_account_id, 'não pode ser igual à conta de origem')
    end
  end
end