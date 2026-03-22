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

      # Determine transaction type - installments are usually expenses
      transaction_type = "expense" # InstallmentPlans are typically for expenses like purchases
      amount = plan.installment_amount || 0

      if amount <= 0
        Rails.logger.warn "Invalid amount for installment plan #{plan.name}: #{amount}"
        next
      end

      # Build entries based on transaction type
      entries_attributes = case transaction_type
      when "income"
        [
          { account_id: plan.to_account_id, entry_type: "debit", amount: amount },
          { account_id: plan.from_account_id, entry_type: "credit", amount: amount }
        ]
      when "expense"
        [
          { account_id: plan.from_account_id, entry_type: "debit", amount: amount },
          { account_id: plan.to_account_id, entry_type: "credit", amount: amount }
        ]
      when "transfer"
        [
          { account_id: plan.to_account_id, entry_type: "debit", amount: amount },
          { account_id: plan.from_account_id, entry_type: "credit", amount: amount }
        ]
      else
        # Default to expense pattern
        [
          { account_id: plan.from_account_id, entry_type: "debit", amount: amount },
          { account_id: plan.to_account_id, entry_type: "credit", amount: amount }
        ]
      end

      result = CreateTransactionService.call(
        description: "#{plan.name} - Parcela ##{plan.transactions.count + 1}",
        amount: amount,
        event_date: Date.current,
        payment_date: plan.next_installment_date(plan.transactions.count + 1) || Date.current,
        transaction_type: transaction_type,
        recurrence_type: "installment",
        entries_attributes: entries_attributes,
        user: plan.user,
        category: plan.category,
        installment_plan: plan
      )

      if result.persisted?
        generated_count += 1
        # Update plan's next payment date
        # Update next installment date (if the plan tracks this)
        # Note: We don't need to update anything as next_installment_date calculates dynamically
      else
        error_count += 1
        Rails.logger.error "Failed to create transaction for installment plan #{plan.id}: #{result.errors.full_messages.to_sentence}"
      end
    end

    Rails.logger.info "GenerateInstallmentTransactionsJob finished. Generated: #{generated_count}, Errors: #{error_count}"

    {
      generated_count: generated_count,
      error_count: error_count,
      errors: [] # Pode ser expandido para incluir erros específicos
    }
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
