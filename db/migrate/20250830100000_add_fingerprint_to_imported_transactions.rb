class AddFingerprintToImportedTransactions < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:imported_transactions, :fingerprint)
      add_column :imported_transactions, :fingerprint, :string, limit: 64
    end
    unless column_exists?(:imported_transactions, :fingerprint_version)
      add_column :imported_transactions, :fingerprint_version, :integer, null: false, default: 1
    end
    unless index_exists?(:imported_transactions, :fingerprint)
      add_index :imported_transactions, :fingerprint
    end
  end
end
