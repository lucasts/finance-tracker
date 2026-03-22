# frozen_string_literal: true

# Service para gerenciar operações de callback de CreditStatement de forma organizada
class CreditStatementCallbackService
  def self.call(credit_statement:, operation:)
    new(credit_statement).send("execute_#{operation}")
  end

  def initialize(credit_statement)
    @statement = credit_statement
  end

  # Executa todas as operações necessárias após save
  def execute_after_save
    update_amount_due unless @statement.skip_amount_update
    auto_update_status unless @statement.skip_status_update
  end

  private

  def update_amount_due
    return if @statement.destroyed?

    # Calculate total amount due from all related transactions
    total_due = calculate_total_amount_due

    # Update only if amount changed to avoid infinite callback loops
    if @statement.amount_due != total_due
      @statement.update_column(:amount_due, total_due)
    end
  end

  def auto_update_status
    return if @statement.destroyed?

    new_status = determine_auto_status

    # Update only if status changed to avoid infinite callback loops
    if @statement.status != new_status
      # Handle paid_on date when status changes to paid
      if new_status == "paid" && @statement.paid_on.nil?
        @statement.update_columns(status: new_status, paid_on: Date.today)
      else
        @statement.update_column(:status, new_status)
      end
    end
  end

  def calculate_total_amount_due
    # Sum all transactions that have a credit entry from the credit card account
    # and are associated with this statement
    Transaction
      .joins(:entries)
      .where(entries: { account: @statement.account, entry_type: "credit" })
      .where(credit_statement: @statement)
      .where(status: [ "confirmed", "pending" ])
      .sum(:amount) || 0.0
  end

  def determine_auto_status
    return "paid" if @statement.amount_due > 0 && @statement.remaining_balance <= 0
    return "overdue" if @statement.due_on.present? && @statement.due_on < Date.current && @statement.amount_due > 0
    "open"
  end
end
