class RemoveAccountReferencesFromTransactions < ActiveRecord::Migration[8.0]
  def change
    # Remove foreign key constraints first
    remove_foreign_key :transactions, column: :from_account_id if foreign_key_exists?(:transactions, :accounts, column: :from_account_id)
    remove_foreign_key :transactions, column: :to_account_id if foreign_key_exists?(:transactions, :accounts, column: :to_account_id)
    
    # Remove indexes
    remove_index :transactions, :from_account_id if index_exists?(:transactions, :from_account_id)
    remove_index :transactions, :to_account_id if index_exists?(:transactions, :to_account_id)
    
    # Remove columns
    remove_column :transactions, :from_account_id, :integer
    remove_column :transactions, :to_account_id, :integer
  end
end
