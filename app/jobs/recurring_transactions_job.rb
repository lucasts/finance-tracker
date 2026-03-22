class RecurringTransactionsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting recurring transactions generation..."

    active_commitments = RecurringCommitment.where(status: :active)
    generated_count = 0

    active_commitments.find_each do |commitment|
      next_date = commitment.next_occurrence_date

      # Generate transactions for the next period if not already exists
      if next_date && next_date <= 1.week.from_now
        unless commitment.transactions.where(event_date: next_date.all_day).exists?
          transaction = generate_transaction_for_commitment(commitment, next_date)
          if transaction.persisted?
            generated_count += 1
            Rails.logger.info "Generated transaction for commitment: #{commitment.name} on #{next_date}"
          else
            Rails.logger.error "Failed to generate transaction for commitment #{commitment.id}: #{transaction.errors.full_messages}"
          end
        end
      end
    end

    Rails.logger.info "Finished generating #{generated_count} recurring transactions"
  end

  private

  def generate_transaction_for_commitment(commitment, occurrence_date)
    Rails.logger.info "Processing recurring commitment: #{commitment.name}"

    # Get the most recent transaction from this commitment as template
    template_transaction = commitment.transactions.order(created_at: :desc).first
    amount = template_transaction&.amount || commitment.default_amount || 0

    if amount <= 0
      Rails.logger.warn "Invalid amount for commitment #{commitment.name}: #{amount}"
      return Transaction.new # Return an invalid transaction
    end

    # Determine transaction type from commitment or category
    transaction_type = determine_transaction_type(commitment)

    # Use CreateTransactionService to ensure proper double-entry
    CreateTransactionService.call(
      amount: amount,
      event_date: occurrence_date,
      payment_date: occurrence_date,
      user: commitment.user,
      description: "#{commitment.name} - #{occurrence_date.strftime('%m/%Y')}",
      transaction_type: transaction_type,
      recurrence_type: "recurring",
      category: commitment.category,
      recurring_commitment: commitment,
      entries_attributes: build_entries_for_commitment(commitment, amount, transaction_type)
    )
  end

  def build_entries_for_commitment(commitment, amount, transaction_type)
    # Use the accounts directly from the commitment
    from_account = commitment.from_account
    to_account = commitment.to_account

    case transaction_type
    when "income"
      [
        { account_id: to_account.id, entry_type: "debit", amount: amount },
        { account_id: from_account.id, entry_type: "credit", amount: amount }
      ]
    when "expense"
      [
        { account_id: to_account.id, entry_type: "debit", amount: amount },
        { account_id: from_account.id, entry_type: "credit", amount: amount }
      ]
    when "transfer"
      [
        { account_id: to_account.id, entry_type: "debit", amount: amount },
        { account_id: from_account.id, entry_type: "credit", amount: amount }
      ]
    else
      # Default to expense pattern
      [
        { account_id: to_account.id, entry_type: "debit", amount: amount },
        { account_id: from_account.id, entry_type: "credit", amount: amount }
      ]
    end
  end

  def find_destination_account(commitment, transaction_type)
    # Find appropriate destination account based on category type
    case transaction_type
    when "income"
      # For income, destination should be an asset account (like checking)
      commitment.user.accounts.joins(:account_type).where(account_types: { role: "asset" }).first
    when "expense"
      # For expense, destination should be an expense account
      commitment.user.accounts.joins(:account_type).where(account_types: { role: "expense" }).first ||
        AccountType.find_by(role: "expense")&.accounts&.create!(name: "General Expense", user: commitment.user)
    else
      # Default to first asset account
      commitment.user.accounts.joins(:account_type).where(account_types: { role: "asset" }).first
    end
  end

  def determine_transaction_type(commitment)
    # Most recurring commitments are expenses (bills, subscriptions)
    # Use category type to determine if it's income or expense
    if commitment.category&.income?
      "income"
    else
      "expense"
    end
  end
end
