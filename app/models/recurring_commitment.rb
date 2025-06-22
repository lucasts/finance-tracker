class RecurringCommitment < ApplicationRecord
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
  def next_occurrence_date(from_date = Date.current)
    return nil if closed? || (end_date && from_date > end_date)

    case recurrence_frequency
    when 'weekly'
      from_date.next_week
    when 'monthly'
      from_date.next_month
    when 'annual'
      from_date.next_year
    else
      from_date.next_month # default monthly
    end
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

    confirmed_transactions = transactions.where(status: 'confirmed')
    return 0 if confirmed_transactions.empty?

    confirmed_transactions.average(:amount)&.round(2) || 0
  end

  # Total spent on this commitment
  def total_spent
    transactions.where(status: 'confirmed').sum(:amount)
  end

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

  # Calculate next occurrence after a specific date
  def next_occurrence_after(date)
    case frequency
    when 'weekly'
      date + 1.week
    when 'monthly'
      date + 1.month
    when 'quarterly'
      date + 3.months
    when 'yearly'
      date + 1.year
    else
      date + 1.month # default to monthly
    end
  end

  # Get analysis for this commitment's spending pattern
  def expense_analysis(timeframe_months: 12)
    return nil unless category.present?

    VariableExpenseAnalysisService.new(
      category,
      timeframe_months: timeframe_months
    ).call
  end

  # Check if this commitment generates variable expenses that should be analyzed
  def generates_variable_expenses?
    variable_categories = ['supermercado', 'farmácia', 'gasolina', 'consultas', 'mercado', 'combustível']
    variable_categories.any? { |keyword| name.downcase.include?(keyword) || category.name.downcase.include?(keyword) }
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

  def accounts_must_be_different
    if from_account_id == to_account_id
      errors.add(:to_account_id, 'não pode ser igual à conta de origem')
    end
  end
end