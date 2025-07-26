class Transaction < ApplicationRecord
  include AmountNormalization
  include MoneyParsingConcern
  
  # User associations
  belongs_to :user
  
  # Existing associations
  belongs_to :category, optional: true
  belongs_to :credit_statement, optional: true
  
  # Associations for the robust model
  belongs_to :recurring_commitment, optional: true
  belongs_to :installment_plan, optional: true

  has_many :entries, foreign_key: 'transaction_id', dependent: :destroy, inverse_of: :transaction_record
  has_many :accounts, through: :entries

  accepts_nested_attributes_for :entries

  validates :description, :amount, :event_date, :payment_date, :transaction_type, presence: true
  validates :status, inclusion: { in: %w[pending confirmed cancelled] }
  validate :balance_of_entries
  
  # Mutual exclusivity validation - transaction can only belong to ONE type
  validate :exclusive_association_validation
  
  # Validation to ensure compatibility between transaction_type and category_type
  validate :category_type_compatibility
  
  # Specific validations for transfers
  validate :category_for_transaction_type
  
  # Callbacks for status automation - refactored to use service
  before_validation :set_default_status, if: :new_record?
  before_save :execute_before_save_operations
  after_create :execute_after_create_operations
  after_save :execute_after_save_operations
  
  # Scopes that work with Date using ranges (more efficient)
  scope :in_competence_month, ->(date) { 
    month_start = date.beginning_of_month
    month_end = date.end_of_month
    where(event_date: month_start..month_end)
  }
  scope :in_payment_month, ->(date) { 
    month_start = date.beginning_of_month
    month_end = date.end_of_month
    where(payment_date: month_start..month_end)
  }
  
  scope :upcoming_payments, ->(limit = 10) {
  where(status: ['pending', 'confirmed'])
    .where('event_date > ?', Date.current)
    .where('event_date <= ?', 1.months.from_now)
    .order(:event_date)
    .limit(limit)
  }

  enum :status, { pending: 0, confirmed: 1, cancelled: 2 }
  enum :transaction_type, { income: 0, expense: 1, transfer: 2 }
  enum :recurrence_type, { single: 0, recurring: 1, installment: 2 }
  
  scope :income, -> { where transaction_type: :income }
  scope :expense, -> { where transaction_type: :expense }
  scope :transfer, -> { where transaction_type: :transfer }
  scope :single_transactions, -> { where recurrence_type: :single }
  scope :from_recurring_commitment, ->(commitment) { where(recurring_commitment: commitment) }
  scope :from_installment_plan, ->(plan) { where(installment_plan: plan) }
  
  # Derives competence (YYYY-MM) from event_date
  def competence_month
    event_date.strftime('%Y-%m') if event_date.present?
  end

  # Derives payment month (default: payment_date, fallback to event_date)
  def payment_month
    (payment_date || event_date)&.strftime('%Y-%m')
  end
  
  # Method to determine if the transaction is future
  def future_transaction?
    payment_date && payment_date > Date.current
  end
  
  # Method to check if it should be pending
  def should_be_pending?
    future_transaction? && !cancelled?
  end
  
  # Method to check if it should be confirmed
  def should_be_confirmed?
    !future_transaction? && !cancelled?
  end
  
  # Helper methods for transaction classification
  def single_transaction?
    recurrence_type == 'single'
  end
  
  def recurring_transaction?
    recurrence_type == 'recurring' && recurring_commitment.present?
  end
  
  def installment_transaction?
    recurrence_type == 'installment' && installment_plan.present?
  end
  
  # Installment status (if applicable)
  def installment_status
    return nil unless installment_transaction?
    return nil unless installment_plan.present?
    
    "#{installment_number}/#{installment_plan.installment_count}"
  end
  
  # Name of associated commitment or plan
  def recurring_name
    return installment_plan.name if installment_transaction?
    return recurring_commitment.name if recurring_transaction?
    nil
  end
  
  def set_default_status
    return if status.present?
    
    self.status = determine_automatic_status
  end
  
  def auto_update_status_if_needed
    # Only updates automatically if not explicitly cancelled
    return if cancelled?
    
    # If dates changed, recalculate status
    if payment_date_changed? || event_date_changed?
      new_status = determine_automatic_status
      self.status = new_status unless status == 'cancelled'
    end
  end
  
  def determine_automatic_status
    current_date = Date.current
    check_date = payment_date || event_date
    
    if check_date && check_date > current_date
      'pending'    # Future transaction
    else
      # For installment plan transactions, use different logic
      if installment_plan.present? && installment_number.present?
        # First installment can be confirmed if in the past/present
        # Other installments always pending until manually paid
        if installment_number == 1 && check_date <= current_date
          'confirmed'
        else
          'pending'
        end
      else
        'confirmed'  # Current or past transaction (except installments)
      end
    end
  end
  
  # Mutual exclusivity validation: a transaction can only belong to one type
  def exclusive_association_validation
    associations = [recurring_commitment_id, installment_plan_id].compact
    
    if associations.size > 1
      errors.add(:base, "Transaction can only belong to one type: recurring commitment or installment plan")
    end
    
    # Validate consistency between recurrence_type and associations
    case recurrence_type
    when 'recurring'
      unless recurring_commitment_id.present?
        errors.add(:recurring_commitment, "must be present for recurring transactions")
      end
    when 'installment'
      unless installment_plan_id.present?
        errors.add(:installment_plan, "must be present for installment transactions")
      end
    when 'single'
      if recurring_commitment_id.present? || installment_plan_id.present?
        errors.add(:base, "Single transactions cannot have recurring commitment or installment plan")
      end
    end
  end
  
  # Helper method to determine if status should be auto-updated
  def should_auto_update_status?
    # Never update cancelled transactions
    return false if status == 'cancelled'
    
    # Don't override explicit manual status changes (when status is changed but dates aren't)
    return false if status_changed? && !payment_date_changed? && !event_date_changed?
    
    # Allow updates when dates change, regardless of current status
    true
  end
  
  def category_type_compatibility
    return unless category && transaction_type
    return if transfer? # Transfers don't have category
    
    expected_category_type = transaction_type == 'income' ? 'income' : 'expense'
    
    unless category.category_type == expected_category_type
      category_type_label = category.category_type == 'income' ? 'receita' : 'despesa'
      transaction_type_label = transaction_type == 'income' ? 'receita' : 'despesa'
      
      errors.add(:category, "é do tipo #{category_type_label}, mas a transação é do tipo #{transaction_type_label}")
    end
  end

  def category_for_transaction_type
    if transfer?
      errors.add(:category_id, "Transferência não deve ter categoria") if category_id.present?
    else
      errors.add(:category_id, "Categoria obrigatória") if category_id.blank?
    end
  end

  # Ensures credit statement exists for credit card transactions
  def ensure_credit_statement
    return unless credit_card_transaction?
    return if credit_statement.present? # Already associated

    statement = CreditStatementService.find_or_create_for_transaction(self)
    update_column(:credit_statement_id, statement.id) if statement
  end

  # Checks if this is a credit card transaction
  # Entry-based methods for double-entry bookkeeping
  def debit_entries
    entries.where(entry_type: 'debit')
  end

  def credit_entries
    entries.where(entry_type: 'credit')
  end

  def debit_accounts
    debit_entries.includes(:account).map(&:account)
  end

  def credit_accounts
    credit_entries.includes(:account).map(&:account)
  end

  # For simple transactions with one debit and one credit
  def primary_debit_account
    debit_entries.first&.account
  end

  def primary_credit_account
    credit_entries.first&.account
  end

  def credit_card_transaction?
    entries.joins(:account).where(accounts: { account_type: AccountType.where(code: "CREDIT_CARD") }).where(entry_type: 'credit').exists?
  end

  private

  # Refactored callback methods using service pattern
  def execute_before_save_operations
    TransactionCallbackService.new(self).execute_before_save
  end

  def execute_after_create_operations
    TransactionCallbackService.new(self).execute_after_create
  end

  def execute_after_save_operations
    TransactionCallbackService.new(self).execute_after_save
  end

  # Legacy method kept for backward compatibility - delegated to service
  def update_credit_statement_amount
    return unless credit_statement.present?
    
    # Use the service to update the statement amount
    CreditStatementService.update_statement_amount(credit_statement)
  end

  def balance_of_entries
    return if entries.empty?

    total = entries.reduce(0) do |sum, entry|
      if entry.debit?
        sum + entry.amount
      else
        sum - entry.amount
      end
    end

    errors.add(:base, 'The sum of debits and credits must be zero.') unless total.zero?
  end
end