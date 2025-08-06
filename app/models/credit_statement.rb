class CreditStatement < ApplicationRecord
  include AmountNormalization
  include MoneyConcern
  include FinancialConstants
  
  belongs_to :account
  has_many :transactions, dependent: :nullify

  enum :status, { open: 0, paid: 1, overdue: 2 }

  validates :month, presence: true, format: { with: /\A\d{4}-\d{2}\z/ }
  validates :amount_due, :amount_paid, presence: true
  validate :account_must_be_credit_card
  
  # Refactored callbacks to use service pattern
  after_save :execute_after_save_operations

  attr_accessor :skip_status_update, :skip_amount_update

  def remaining_balance
    amount_due - amount_paid
  end

  private

  def account_must_be_credit_card
    if account&.account_type&.code != "CREDIT_CARD"
      errors.add(:account, "deve ser uma conta do tipo cartão de crédito")
    end
  end

  def auto_update_status
    return if skip_status_update
    
    new_status = nil
    new_paid_on = paid_on
    
    if amount_due > 0 && amount_paid >= amount_due
      new_status = :paid
      new_paid_on ||= Date.today
    elsif due_on.present? && due_on < Date.today && amount_paid < amount_due && amount_due > 0
      new_status = :overdue
    else
      new_status = :open
    end
    
    # Only update if status actually changed to avoid infinite loops
    if new_status != status.to_sym || new_paid_on != paid_on
      self.status = new_status
      self.paid_on = new_paid_on
      # Don't save here to avoid infinite loop - let the original save continue
    end
  end
  
  def update_amount_due
    return if skip_amount_update
    
    old_amount_due = amount_due
    CreditStatementService.update_statement_amount(self)
    
    # Reload to get the updated amount_due from the service
    reload
    
    # If amount_due changed, we need to re-check status
    if amount_due != old_amount_due
      auto_update_status
      save! if changed?
    end
  end
  
  # Create without updating amount_due (for service use)
  def self.create_with_defaults!(attributes = {})
    statement = new(attributes)
    statement.skip_amount_update = true
    statement.save!
    statement.skip_amount_update = false
    statement
  end

  private

  # Refactored callback method using service pattern
  def execute_after_save_operations
    CreditStatementCallbackService.call(credit_statement: self, operation: :after_save)
  end
end