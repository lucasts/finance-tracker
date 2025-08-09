class AddPossibleDuplicateToImportedTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :imported_transactions, :possible_duplicate, :boolean, null: false, default: false
    add_index :imported_transactions, :possible_duplicate
  end
end
