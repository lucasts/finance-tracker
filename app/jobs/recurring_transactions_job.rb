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
        unless commitment.transactions.exists?(event_date: next_date)
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
    # Use the most recent transaction as a template for account information
    template_transaction = commitment.transactions.order(:event_date).last
    
    amount = if commitment.fixed_amount?
      commitment.expected_amount
    else
      commitment.expected_amount || commitment.average_amount
    end

    Transaction.create(
      description: commitment.name,
      amount: amount,
      transaction_type: template_transaction&.transaction_type || determine_transaction_type(commitment),
      event_date: occurrence_date,
      payment_date: occurrence_date,
      from_account: template_transaction&.from_account || default_account_for_commitment(commitment),
      to_account: template_transaction&.to_account,
      category: commitment.category,
      recurring_commitment: commitment,
      recurrence_type: 'recurring',
      status: occurrence_date > Date.current ? 'pending' : 'confirmed',
      user: commitment.user
    )
  end

  def determine_transaction_type(commitment)
    # Analyze category to determine if it's income or expense
    category_name = commitment.category.name.downcase
    
    income_keywords = ['salário', 'freelance', 'renda', 'receita', 'dividend']
    expense_keywords = ['aluguel', 'conta', 'assinatura', 'mensalidade', 'plano']
    
    if income_keywords.any? { |keyword| category_name.include?(keyword) }
      'income'
    elsif expense_keywords.any? { |keyword| category_name.include?(keyword) }
      'expense'
    else
      'expense' # default to expense for recurring commitments
    end
  end

  def default_account_for_commitment(commitment)
    # Return the most commonly used account for this category
    Account.joins(:transactions_from)
           .where(transactions: { category: commitment.category })
           .group('accounts.id')
           .order('COUNT(transactions.id) DESC')
           .first || Account.first
  end
end
