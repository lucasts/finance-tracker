# frozen_string_literal: true

# Service para gerenciar operações de callback de Transaction de forma organizada
class TransactionCallbackService
  def self.call(transaction:, operation:)
    new(transaction).send("execute_#{operation}")
  end

  def initialize(transaction)
    @transaction = transaction
  end

  # Executa todas as operações necessárias após criação
  def execute_after_create
    ensure_credit_statement
    update_credit_statement_amount
    update_account_balances
  end

  # Executa todas as operações necessárias após save
  def execute_after_save
    update_credit_statement_amount if should_update_credit_statement?
    update_account_balances if should_update_account_balances?
  end

  # Executa operações necessárias antes de save
  def execute_before_save
    auto_update_status_if_needed
  end

  private

  def ensure_credit_statement
    # Find if any of the credit entries come from a credit card account
    credit_card_account = @transaction.entries.joins(:account)
      .where(entry_type: 'credit', accounts: { account_type: AccountType.find_by(code: 'CREDIT_CARD') })
      .first&.account
    
    return unless credit_card_account&.credit_card?
    return if @transaction.credit_statement.present? # Already associated
    
    statement = CreditStatementService.find_or_create_for_transaction(@transaction)
    @transaction.update_column(:credit_statement_id, statement.id) if statement
  end

  def update_credit_statement_amount
    # Find if any of the credit entries come from a credit card account
    credit_card_account = @transaction.entries.joins(:account)
      .where(entry_type: 'credit', accounts: { account_type: AccountType.find_by(code: 'CREDIT_CARD') })
      .first&.account
    
    return unless credit_card_account&.credit_card?
    
    # Find the credit statement for this transaction
    statement = CreditStatementService.find_or_create_for_transaction(@transaction)
    CreditStatementService.update_statement_amount(statement) if statement
  end

  def should_update_credit_statement?
    # Check if any credit entry comes from a credit card account
    has_credit_card_entry = @transaction.entries.joins(:account)
      .where(entry_type: 'credit', accounts: { account_type: AccountType.find_by(code: 'CREDIT_CARD') })
      .exists?
    
    has_credit_card_entry && 
      (@transaction.saved_change_to_amount? || @transaction.saved_change_to_status?)
  end

  def auto_update_status_if_needed
    # Only update status if the transaction allows it
    return unless @transaction.respond_to?(:should_auto_update_status?) && @transaction.should_auto_update_status?
    
    # Use the model's logic for determining status
    if @transaction.respond_to?(:determine_automatic_status)
      @transaction.status = @transaction.determine_automatic_status
    end
  end

  def update_account_balances
    # Update balance cache for all accounts involved in this transaction
    @transaction.accounts.each(&:update_balance_cache!)
  end

  def should_update_account_balances?
    # Update balances when transaction status changes (affects confirmed/pending)
    # or when the transaction is new/modified
    @transaction.saved_change_to_status? || @transaction.saved_change_to_amount?
  end
end
