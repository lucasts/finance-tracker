# Job to generate installment transactions automatically
# Executed periodically to create new installments based on InstallmentPlans
class GenerateInstallmentTransactionsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting GenerateInstallmentTransactionsJob for date: #{Date.current}"
    
    generated_count = 0
    error_count = 0

    InstallmentPlan.where(status: :active).find_each do |plan|
      next unless should_generate_installment?(plan, Date.current)

      entries_attributes = [
        { account_id: plan.to_account_id, entry_type: 'debit', amount: plan.installment_amount },
        { account_id: plan.from_account_id, entry_type: 'credit', amount: plan.installment_amount }
      ]

      result = CreateTransactionService.call(
        description: "#{plan.description} - Parcela ##{plan.transactions.count + 1}",
        amount: plan.installment_amount,
        event_date: Date.current,
        payment_date: plan.next_payment_date || Date.current,
        transaction_type: 'expense', # Or based on plan
        entries_attributes: entries_attributes,
        user: plan.user
      )

      if result.persisted?
        generated_count += 1
      else
        error_count += 1
        Rails.logger.error "Failed to create transaction for installment plan #{plan.id}: #{result.errors.full_messages.to_sentence}"
      end
    end

    Rails.logger.info "GenerateInstallmentTransactionsJob finished. Generated: #{generated_count}, Errors: #{error_count}"
  end

  private

  def should_generate_installment?(plan, date)
    # Check if there are still installments to be generated
    return false if plan.transactions.count >= plan.installment_count

    # Calculate the due date of the next installment
    # The first installment is due on starts_on, the following ones monthly.
    next_due_date = plan.starts_on.months_since(plan.transactions.count)

    # Generate if the next installment's due date is today or has passed
    date >= next_due_date
  end
end
