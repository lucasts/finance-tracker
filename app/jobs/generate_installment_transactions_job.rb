# Job para gerar transações de parcelas automaticamente
# Executado periodicamente para criar novas parcelas baseadas em InstallmentPlans
class GenerateInstallmentTransactionsJob < ApplicationJob
  queue_as :default

  def perform(date = Date.current)
    Rails.logger.info "Starting GenerateInstallmentTransactionsJob for date: #{date}"
    
    # Busca planos de parcelamento ativos que têm parcelas pendentes
    installment_plans = InstallmentPlan.joins("LEFT JOIN transactions ON transactions.installment_plan_id = installment_plans.id")
                                      .where(active: true)
                                      .group('installment_plans.id')
                                      .having('COUNT(transactions.id) < installment_plans.installment_count')
    
    generated_count = 0
    errors = []

    installment_plans.find_each do |plan|
      begin
        if should_generate_installment?(plan, date)
          transaction = create_installment_transaction(plan, date)
          if transaction.persisted?
            generated_count += 1
            Rails.logger.info "Generated installment transaction #{transaction.id} for plan #{plan.id}"
          else
            errors << "Failed to save installment for plan #{plan.id}: #{transaction.errors.full_messages.join(', ')}"
          end
        end
      rescue StandardError => e
        errors << "Error processing installment plan #{plan.id}: #{e.message}"
        Rails.logger.error "Error in GenerateInstallmentTransactionsJob for plan #{plan.id}: #{e.message}"
      end
    end

    Rails.logger.info "GenerateInstallmentTransactionsJob completed. Generated: #{generated_count}, Errors: #{errors.count}"
    
    if errors.any?
      Rails.logger.error "Errors in GenerateInstallmentTransactionsJob: #{errors.join('; ')}"
    end

    { generated: generated_count, errors: errors }
  end

  private

  def should_generate_installment?(plan, date)
    # Verifica quantas parcelas já foram geradas
    existing_count = plan.transactions.count
    return false if existing_count >= plan.installment_count
    
    # Calcula a data da próxima parcela
    next_installment_date = calculate_next_installment_date(plan, existing_count + 1)
    
    # Verifica se é hora de gerar a próxima parcela
    date >= next_installment_date
  end

  def calculate_next_installment_date(plan, installment_number)
    case plan.recurrence_frequency
    when 'monthly'
      plan.starts_on + (installment_number - 1).months
    when 'weekly'
      plan.starts_on + (installment_number - 1).weeks
    when 'daily'
      plan.starts_on + (installment_number - 1).days
    else
      # Default para monthly se frequência não reconhecida
      plan.starts_on + (installment_number - 1).months
    end
  end

  def create_installment_transaction(plan, date)
    existing_count = plan.transactions.count
    installment_number = existing_count + 1
    
    # Calcula a data correta da parcela
    installment_date = calculate_next_installment_date(plan, installment_number)
    
    Transaction.create!(
      description: "#{plan.name} (#{installment_number}/#{plan.installment_count})",
      amount: plan.installment_amount,
      transaction_type: plan.transaction_type,
      date: installment_date,
      account: plan.account,
      category: plan.category,
      installment_plan: plan,
      installment_number: installment_number,
      notes: "Parcela gerada automaticamente pelo sistema"
    )
  end
end
