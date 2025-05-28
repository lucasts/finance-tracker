class RenameAndAddDatesTransactions < ActiveRecord::Migration[7.1]
  def change
    rename_column :transactions, :date, :event_date
    rename_column :transactions, :period, :payment_period

    add_column :transactions, :payment_date, :date
  end
end