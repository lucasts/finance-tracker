class ChangeTransactionDatesToDatetime < ActiveRecord::Migration[8.0]
  # Convert date fields to datetime to preserve time information
  # This allows proper chronological ordering of transactions within the same day
  # and gives users ability to specify transaction time for better accuracy
  
  def up
    # Change event_date from date to datetime
    # Existing dates will be converted to datetime at 00:00:00 in database timezone
    change_column :transactions, :event_date, :datetime
    
    # Change payment_date from date to datetime
    change_column :transactions, :payment_date, :datetime
  end

  def down
    # Revert to date (will lose time information)
    change_column :transactions, :event_date, :date
    change_column :transactions, :payment_date, :date
  end
end
