# Job to generate recurring transactions automatically
# Executed periodically to create new transactions based on RecurringCommitments
class GenerateRecurringTransactionsJob < ApplicationJob
  queue_as :default

  def perform(date = Date.current)
    Rails.logger.info "Starting GenerateRecurringTransactionsJob for date: #{date}"
    
    # Find active recurring commitments
    recurring_commitments = RecurringCommitment.where(status: :active)
    
    generated_count = 0
    errors = []

    recurring_commitments.find_each do |commitment|
      begin
        if should_generate_transaction?(commitment, date)
          transaction = create_transaction_for_commitment(commitment, date)
          if transaction.persisted?
            generated_count += 1
            Rails.logger.info "Generated transaction #{transaction.id} for commitment #{commitment.id}"
          else
            errors << "Failed to save transaction for commitment #{commitment.id}: #{transaction.errors.full_messages.join(', ')}"
          end
        end
      rescue StandardError => e
        errors << "Error processing commitment #{commitment.id}: #{e.message}"
        Rails.logger.error "Error in GenerateRecurringTransactionsJob for commitment #{commitment.id}: #{e.message}"
      end
    end

    Rails.logger.info "GenerateRecurringTransactionsJob completed. Generated: #{generated_count}, Errors: #{errors.count}"
    
    if errors.any?
      Rails.logger.error "Errors in GenerateRecurringTransactionsJob: #{errors.join('; ')}"
    end

    { generated_count: generated_count, errors: errors }
  end

  private

  def should_generate_transaction?(commitment, date)
    # Verifica se já existe transação para esta data
    return false if transaction_exists_for_date?(commitment, date)
    
    # Verifica se está dentro do período ativo
    return false if commitment.start_date > date
    return false if commitment.end_date.present? && commitment.end_date < date
    
    # Verifica se é dia de gerar baseado na frequência
    case commitment.recurrence_frequency
    when 'daily'
      true
    when 'weekly'
      date.wday == commitment.start_date.wday
    when 'monthly'
      is_monthly_generation_day?(commitment, date)
    when 'annual'
      date.month == commitment.start_date.month && date.day == commitment.start_date.day
    else
      false
    end
  end

  def is_monthly_generation_day?(commitment, date)
    target_day = commitment.start_date.day
    
    # Se o dia do mês é maior que os dias disponíveis no mês atual, usar o último dia
    if target_day > date.end_of_month.day
      date == date.end_of_month
    else
      date.day == target_day
    end
  end

  def transaction_exists_for_date?(commitment, date)
    Transaction.exists?(
      recurring_commitment: commitment,
      event_date: date
    )
  end

  def create_transaction_for_commitment(commitment, date)
    # Determina contas baseado nas transações anteriores ou usa padrões
    recent_transaction = commitment.transactions.order(:event_date).last
    
    # Define o tipo de transação baseado na categoria
    transaction_type = determine_transaction_type(commitment)
    
    # Define contas baseadas no tipo de transação
    if transaction_type == 'income'
      # Para receitas: empresa/fonte -> conta bancária
      from_account = recent_transaction&.from_account || find_revenue_account(commitment)
      to_account = recent_transaction&.to_account || find_bank_account(commitment.user)
    else
      # Para despesas: conta bancária -> categoria de despesa
      from_account = recent_transaction&.from_account || find_bank_account(commitment.user)
      to_account = recent_transaction&.to_account || find_expense_account(commitment)
    end

    Transaction.create!(
      description: commitment.name,
      amount: commitment.default_amount || 0,
      transaction_type: transaction_type,
      event_date: date,
      payment_date: date,
      from_account: from_account,
      to_account: to_account,
      category: commitment.category,
      recurring_commitment: commitment,
      recurrence_type: 'recurring',
      status: 'confirmed',
      user: commitment.user
    )
  end

  private

  def determine_transaction_type(commitment)
    # Análise da categoria para determinar tipo
    category_name = commitment.category.name.downcase
    
    income_keywords = ['salário', 'freelance', 'renda', 'receita', 'dividend']
    
    if income_keywords.any? { |keyword| category_name.include?(keyword) }
      'income'
    else
      'expense'
    end
  end

  def find_bank_account(user)
    Account.joins(:account_type)
           .where(user: user, account_types: { code: 'BANK' })
           .first || Account.where(user: user).first
  end

  def find_revenue_account(commitment)
    Account.joins(:account_type)
           .where(user: commitment.user, account_types: { code: 'REVENUE' })
           .first || Account.where(user: commitment.user).first
  end

  def find_expense_account(commitment)
    Account.joins(:account_type)
           .where(user: commitment.user, account_types: { code: 'EXPENSE' })
           .first || Account.where(user: commitment.user).first
  end
end
