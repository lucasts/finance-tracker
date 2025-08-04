# Job to generate recurring transactions automatically
# Executed periodically to create new transactions based on RecurringCommitments
class GenerateRecurringTransactionsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting GenerateRecurringTransactionsJob for date: #{Date.current}"
    
    generated_count = 0
    error_count = 0

    RecurringCommitment.where(status: :active).find_each do |commitment|
      next unless should_generate_transaction?(commitment, Date.current)

      # Determine transaction type from commitment or category
      transaction_type = determine_transaction_type(commitment)
      amount = commitment.default_amount || 0
      
      if amount <= 0
        Rails.logger.warn "Invalid amount for commitment #{commitment.name}: #{amount}"
        next
      end

      # Build entries based on transaction type
      entries_attributes = case transaction_type
      when 'income'
        [
          { account_id: commitment.to_account_id, entry_type: 'debit', amount: amount },
          { account_id: commitment.from_account_id, entry_type: 'credit', amount: amount }
        ]
      when 'expense'
        [
          { account_id: commitment.from_account_id, entry_type: 'debit', amount: amount },
          { account_id: commitment.to_account_id, entry_type: 'credit', amount: amount }
        ]
      when 'transfer'
        [
          { account_id: commitment.to_account_id, entry_type: 'debit', amount: amount },
          { account_id: commitment.from_account_id, entry_type: 'credit', amount: amount }
        ]
      else
        # Default to expense pattern
        [
          { account_id: commitment.from_account_id, entry_type: 'debit', amount: amount },
          { account_id: commitment.to_account_id, entry_type: 'credit', amount: amount }
        ]
      end

      result = CreateTransactionService.call(
        description: commitment.name,
        amount: amount,
        event_date: Date.current,
        payment_date: Date.current,
        transaction_type: transaction_type,
        recurrence_type: 'recurring',
        entries_attributes: entries_attributes,
        user: commitment.user,
        category: commitment.category,
        recurring_commitment: commitment
      )

      if result.persisted?
        generated_count += 1
      else
        error_count += 1
        Rails.logger.error "Failed to create transaction for commitment #{commitment.id}: #{result.errors.full_messages.to_sentence}"
      end
    end

    Rails.logger.info "GenerateRecurringTransactionsJob finished. Generated: #{generated_count}, Errors: #{error_count}"
    
    {
      generated_count: generated_count,
      error_count: error_count,
      errors: [] # Pode ser expandido para incluir erros específicos
    }
  end

  private

  def determine_transaction_type(commitment)
    # Use category type to determine transaction type
    if commitment.category&.income?
      'income'
    else
      'expense' # default to expense for recurring commitments
    end
  end

  def should_generate_transaction?(commitment, date)
    last_transaction_date = commitment.transactions.order(event_date: :desc).first&.event_date

    # If it has never been generated, and the start date has passed, generate the first one.
    unless last_transaction_date
      return date >= commitment.start_date
    end

    # Logic based on frequency
    case commitment.recurrence_frequency.to_sym
    when :monthly
      # If the last transaction was at least a month ago and the day of the month is correct
      (last_transaction_date.next_month.beginning_of_month + (commitment.start_date.day - 1).days) <= date
    when :yearly
      # If the last transaction was at least a year ago and the month/day is correct
      (last_transaction_date.next_year.beginning_of_year + (commitment.start_date.yday - 1).days) <= date
    when :weekly
      # If the last transaction was at least a week ago
      (last_transaction_date + 1.week) <= date
    else
      false # Other frequencies not implemented or invalid
    end
  end
end
