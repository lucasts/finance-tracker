class AddTransferDetectionToImportedTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :imported_transactions, :transfer_candidate, :boolean, null: false, default: false
    add_column :imported_transactions, :potential_transfer_with_id, :bigint, null: true
    
    add_index :imported_transactions, :transfer_candidate
    add_index :imported_transactions, :potential_transfer_with_id
  end
end
