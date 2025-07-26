class AddAccountsToCommitmentsAndPlans < ActiveRecord::Migration[8.0]
  def change
    # Add columns to recurring_commitments only if they don't exist
    unless column_exists?(:recurring_commitments, :from_account_id)
      add_reference :recurring_commitments, :from_account, foreign_key: { to_table: :accounts }
    end
    unless column_exists?(:recurring_commitments, :to_account_id)
      add_reference :recurring_commitments, :to_account, foreign_key: { to_table: :accounts }
    end

    # Add columns to installment_plans only if they don't exist
    unless column_exists?(:installment_plans, :from_account_id)
      add_reference :installment_plans, :from_account, foreign_key: { to_table: :accounts }
    end
    unless column_exists?(:installment_plans, :to_account_id)
      add_reference :installment_plans, :to_account, foreign_key: { to_table: :accounts }
    end
  end
end
