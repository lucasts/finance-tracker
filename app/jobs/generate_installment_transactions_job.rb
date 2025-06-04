# Job para gerar transações de parcelas automaticamente
# Executado periodicamente para criar novas parcelas baseadas em InstallmentPlans
class GenerateInstallmentTransactionsJob < ApplicationJob
  queue_as :default

  def perform(date = Date.current)
    Rails.logger.info "Starting GenerateInstallmentTransactionsJob for date: #{date}"
    
    # Busca planos de parcelamento ativos que têm parcelas pendentes
    installment_plans = InstallmentPlan.joins("LEFT JOIN transactions ON transactions.installment_plan_id = installment_plans.id")
                                      .where(status: :active)
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

    { generated_count: generated_count, errors: errors }
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
    
    # Calcula o valor da parcela
    installment_amount = plan.total_amount ? (plan.total_amount / plan.installment_count) : 0
    
    # Busca template de transação anterior ou define padrões
    template_transaction = plan.transactions.order(:event_date).last
    
    Transaction.create!(
      description: "#{plan.name} (#{installment_number}/#{plan.installment_count})",
      amount: installment_amount,
      transaction_type: 'expense', # Parcelas são geralmente despesas
      event_date: installment_date,
      payment_date: installment_date,
      from_account: template_transaction&.from_account || find_default_account(plan.user),
      to_account: template_transaction&.to_account || find_expense_account(plan.user),
      category: template_transaction&.category || find_default_category(plan.user),
      installment_plan: plan,
      recurrence_type: 'installment',
      status: installment_date <= Date.current ? 'confirmed' : 'pending',
      user: plan.user
    )
  end

  private

  def find_default_account(user)
    Account.joins(:account_type)
           .where(user: user, account_types: { code: 'BANK' })
           .first || Account.where(user: user).first
  end

  def find_expense_account(user)
    Account.joins(:account_type)
           .where(user: user, account_types: { code: 'EXPENSE' })
           .first
  end

  def find_default_category(user)
    Category.where(user: user).first || Category.create!(user: user, name: 'Parcelamento')
  end
end
