class RenameAndAddDatesTransactions < ActiveRecord::Migration[7.1]
  def change
    rename_column :transactions, :date, :event_date
    remove_column :transactions, :period

    add_column :transactions, :payment_date, :date
  end
end