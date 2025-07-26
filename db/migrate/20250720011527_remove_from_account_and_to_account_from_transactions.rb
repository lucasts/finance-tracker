class RemoveFromAccountAndToAccountFromTransactions < ActiveRecord::Migration[8.0]
  def change
    remove_column :transactions, :from_account_id, :integer
    remove_column :transactions, :to_account_id, :integer
  end
end
