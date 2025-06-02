class AutomationController < ApplicationController
  before_action :set_date_range, only: [:index]

  def index
    @recent_jobs = []
    @automation_stats = calculate_automation_stats
  end

  def run_daily
    job = AutomationJob.run_daily_automation
    redirect_to automation_index_path, notice: 'Automação diária iniciada. Os resultados aparecerão em breve.'
  end

  def run_recurring
    job = AutomationJob.run_recurring_only
    redirect_to automation_index_path, notice: 'Geração de transações recorrentes iniciada.'
  end

  def run_installments
    job = AutomationJob.run_installments_only
    redirect_to automation_index_path, notice: 'Geração de parcelas iniciada.'
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
