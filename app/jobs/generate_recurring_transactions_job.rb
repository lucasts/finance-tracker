# Job para gerar transações recorrentes automaticamente
# Executado periodicamente para criar novas transações baseadas em RecurringCommitments
class GenerateRecurringTransactionsJob < ApplicationJob
  queue_as :default

  def perform(date = Date.current)
    Rails.logger.info "Starting GenerateRecurringTransactionsJob for date: #{date}"
    
    # Busca compromissos recorrentes ativos
    recurring_commitments = RecurringCommitment.where(active: true)
    
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

    { generated: generated_count, errors: errors }
  end

  private

  def should_generate_transaction?(commitment, date)
    # Verifica se já existe transação para esta data
    return false if transaction_exists_for_date?(commitment, date)
    
    # Verifica se está dentro do período ativo
    return false if commitment.start_date > date
    return false if commitment.end_date.present? && commitment.end_date < date
    
    # Verifica se é dia de gerar baseado na frequência
    case commitment.frequency
    when 'daily'
      true
    when 'weekly'
      date.wday == commitment.start_date.wday
    when 'monthly'
      is_monthly_generation_day?(commitment, date)
    when 'yearly'
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
      date: date
    )
  end

  def create_transaction_for_commitment(commitment, date)
    Transaction.create!(
      description: commitment.name,
      amount: commitment.amount,
      transaction_type: commitment.transaction_type,
      date: date,
      account: commitment.account,
      category: commitment.category,
      recurring_commitment: commitment,
      notes: "Gerado automaticamente pelo sistema"
    )
  end
end
