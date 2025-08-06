class PopulateAccountBalances < ActiveRecord::Migration[8.0]
  def up
    say "Populating account balances..."
    
    Account.find_each do |account|
      calculated_balance = calculate_balance_for_account(account)
      account.update_column(:balance, calculated_balance)
      say "Updated account #{account.name}: #{calculated_balance}", true
    end
    
    say "Finished populating #{Account.count} account balances"
  end

  def down
    say "Resetting all account balances to 0..."
    Account.update_all(balance: 0)
  end

  private

  def calculate_balance_for_account(account)
    return BigDecimal('0') if account.account_type.nil?
    
    debit_total = Entry.joins(:transaction_record, :account)
      .where(
        account_id: account.id,
        transactions: { status: 'confirmed' }, 
        entry_type: 'debit'
      ).sum(:amount) || BigDecimal('0')
    
    credit_total = Entry.joins(:transaction_record, :account)
      .where(
        account_id: account.id,
        transactions: { status: 'confirmed' }, 
        entry_type: 'credit'
      ).sum(:amount) || BigDecimal('0')
    
    if account.account_type.asset_type?
      debit_total - credit_total
    else
      credit_total - debit_total
    end
  end
end
