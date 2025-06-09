class AddAccountsToRecurringCommitments < ActiveRecord::Migration[7.1]
  def change
    add_reference :recurring_commitments, :from_account, null: false, foreign_key: { to_table: :accounts }
    add_reference :recurring_commitments, :to_account, null: false, foreign_key: { to_table: :accounts }
  end
end
