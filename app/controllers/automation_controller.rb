class AutomationController < ApplicationController
  before_action :set_date_range, only: [:index]

  def index
    @recent_jobs = []
    @automation_stats = calculate_automation_stats
  end

  def run_daily
    # Para facilitar testes, permite executar com data futura
    test_date = params[:test_date].present? ? Date.parse(params[:test_date]) : Date.current
    AutomationJob.perform_later(['recurring', 'installments'], test_date)
    redirect_to automation_index_path, notice: "Automação diária iniciada para data #{test_date}. Os resultados aparecerão em breve."
  end

  def run_recurring
    # Para facilitar testes, permite executar com data futura
    test_date = params[:test_date].present? ? Date.parse(params[:test_date]) : Date.current
    AutomationJob.perform_later(['recurring'], test_date)
    redirect_to automation_index_path, notice: "Geração de transações recorrentes iniciada para data #{test_date}."
  end

  def run_installments
    # Para facilitar testes, permite executar com data futura
    test_date = params[:test_date].present? ? Date.parse(params[:test_date]) : Date.current
    AutomationJob.perform_later(['installments'], test_date)
    redirect_to automation_index_path, notice: "Geração de parcelas iniciada para data #{test_date}."
  end
  
  # Preview de automações que serão executadas para uma data específica
  def preview
    @date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    
    @preview_results = {
      recurring_transactions: [],
      installment_transactions: []
    }

    # Instancia o job para usar seus métodos (sem executá-lo)
    recurring_job = GenerateRecurringTransactionsJob.new
    
    # Verifica cada compromisso recorrente ativo
    RecurringCommitment.where(status: :active).each do |commitment|
      # Verifica se o compromisso deve gerar transação na data
      should_generate = recurring_job.send(:should_generate_transaction?, commitment, @date)
      exists = recurring_job.send(:transaction_exists_for_date?, commitment, @date)
      
      # Adiciona informações para exibição
      @preview_results[:recurring_transactions] << {
        id: commitment.id,
        name: commitment.name,
        should_generate: should_generate,
        already_exists: exists,
        frequency: commitment.recurrence_frequency,
        generation_day: commitment.recurrence_frequency == 'monthly' ? commitment.start_date.day : nil,
        start_date: commitment.start_date
      }
    end

    # Faz o mesmo para parcelamentos
    installment_job = GenerateInstallmentTransactionsJob.new
    
    InstallmentPlan.where(status: :active).each do |plan|
      should_generate = installment_job.send(:should_generate_installment?, plan, @date)
      existing_count = plan.transactions.count
      
      @preview_results[:installment_transactions] << {
        id: plan.id,
        name: plan.name,
        should_generate: should_generate,
        current_installment: existing_count,
        total_installments: plan.installment_count,
        frequency: plan.recurrence_frequency,
        start_date: plan.starts_on
      }
    end
    
    respond_to do |format|
      format.html
      format.json { render json: @preview_results }
    end
  end

  def status
    # Em uma implementação real, você consultaria o status dos jobs
    render json: {
      status: 'completed',
      last_run: Time.current,
      next_run: Time.current + 1.day,
      results: {
        recurring_transactions: 5,
        installment_transactions: 3,
        errors: []
      }
    }
  end

  private

  def set_date_range
    @start_date = params[:start_date]&.to_date || Date.current.beginning_of_month
    @end_date = params[:end_date]&.to_date || Date.current.end_of_month
  end

  def calculate_automation_stats
    {
      active_recurring_commitments: RecurringCommitment.active_commitments.count,
      active_installment_plans: InstallmentPlan.active_plans.count,
      transactions_this_month: Transaction.where(created_at: @start_date..@end_date).count,
      recurring_transactions_this_month: Transaction.joins(:recurring_commitment)
                                                    .where(created_at: @start_date..@end_date)
                                                    .count,
      installment_transactions_this_month: Transaction.joins(:installment_plan)
                                                     .where(created_at: @start_date..@end_date)
                                                     .count
    }
  end
end
