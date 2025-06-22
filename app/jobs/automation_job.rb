# Job to execute manual system automations
class AutomationJob < ApplicationJob
  queue_as :default

  def perform(job_types = ['recurring', 'installments'], date = Date.current)
    Rails.logger.info "Starting AutomationJob with types: #{job_types}, date: #{date}"
    
    results = {
      recurring_transactions: 0,
      installment_transactions: 0,
      errors: []
    }

    begin
      # Execute recurring transactions generation
      if job_types.include?('recurring')
        recurring_job = GenerateRecurringTransactionsJob.new
        recurring_result = recurring_job.perform(date)
        results[:recurring_transactions] = recurring_result[:generated_count] if recurring_result.is_a?(Hash)
      end

      # Execute installment generation
      if job_types.include?('installments')
        installment_job = GenerateInstallmentTransactionsJob.new
        installment_result = installment_job.perform(date)
        results[:installment_transactions] = installment_result[:generated_count] if installment_result.is_a?(Hash)
      end

      Rails.logger.info "AutomationJob completed: #{results}"
      results
      
    rescue StandardError => e
      results[:errors] << "Erro na automação: #{e.message}"
      Rails.logger.error "AutomationJob failed: #{e.message}"
      results
    end
  end

  # Convenience method to execute full automation
  def self.run_daily_automation(date = Date.current)
    perform_later(['recurring', 'installments'], date)
  end

  # Method to execute only recurring transactions
  def self.run_recurring_only(date = Date.current)
    perform_later(['recurring'], date)
  end

  # Method to execute only installments
  def self.run_installments_only(date = Date.current)
    perform_later(['installments'], date)
  end
end
