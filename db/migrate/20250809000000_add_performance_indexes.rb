class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    add_index :transactions, [:user_id, :status, :event_date], name: 'index_transactions_on_user_status_event_date'
    add_index :entries, [:account_id, :entry_type], name: 'index_entries_on_account_and_type'
  end
end
