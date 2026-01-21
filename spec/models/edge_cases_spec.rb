require 'rails_helper'

RSpec.describe 'Transaction Edge Cases', type: :model do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }
  let(:expense_account) { create(:account, :expense_destination, user: user) }
  let(:category) { create(:category, user: user) }

  it 'creates transaction with extremely high value' do
    tx = CreateTransactionService.call(
      amount: 99_999_999.99, 
      event_date: Date.today, 
      payment_date: Date.today,
      category: category, 
      user: user,
      description: 'Valor extremo',
      transaction_type: 'expense',
      entries_attributes: [
        { account_id: account.id, entry_type: 'debit', amount: 99_999_999.99 },
        { account_id: expense_account.id, entry_type: 'credit', amount: 99_999_999.99 }
      ]
    )
    expect(tx).to be_persisted
  end

  it 'creates transaction with extreme negative value' do
    tx = CreateTransactionService.call(
      amount: 99_999_999.99, 
      event_date: Date.today, 
      payment_date: Date.today,
      category: category, 
      user: user,
      description: 'Valor negativo extremo',
      transaction_type: 'expense',
      entries_attributes: [
        { account_id: account.id, entry_type: 'credit', amount: 99_999_999.99 },
        { account_id: expense_account.id, entry_type: 'debit', amount: 99_999_999.99 }
      ]
    )
    expect(tx).to be_persisted
  end

  it 'creates transaction with very old date' do
    tx = CreateTransactionService.call(
      amount: 100, 
      event_date: Date.new(1900,1,1), 
      payment_date: Date.new(1900,1,1),
      category: category, 
      user: user,
      description: 'Data antiga',
      transaction_type: 'expense',
      entries_attributes: [
        { account_id: account.id, entry_type: 'debit', amount: 100 },
        { account_id: expense_account.id, entry_type: 'credit', amount: 100 }
      ]
    )
    expect(tx).to be_persisted
  end

  it 'creates transaction with very future date' do
    tx = CreateTransactionService.call(
      amount: 100, 
      event_date: Date.new(2099,12,31), 
      payment_date: Date.new(2099,12,31),
      category: category, 
      user: user,
      description: 'Data futura',
      transaction_type: 'expense',
      entries_attributes: [
        { account_id: account.id, entry_type: 'debit', amount: 100 },
        { account_id: expense_account.id, entry_type: 'credit', amount: 100 }
      ]
    )
    expect(tx).to be_persisted
  end

  it 'creates transaction with long description' do
    tx = CreateTransactionService.call(
      amount: 100, 
      event_date: Date.today, 
      payment_date: Date.today,
      category: category, 
      user: user, 
      description: 'a'*500,
      transaction_type: 'expense',
      entries_attributes: [
        { account_id: account.id, entry_type: 'debit', amount: 100 },
        { account_id: expense_account.id, entry_type: 'credit', amount: 100 }
      ]
    )
    expect(tx).to be_persisted
  end

  it 'blocks transaction that is both installment and recurring' do
    installment_plan = create(:installment_plan, user: user)
    recurring_commitment = create(:recurring_commitment, user: user)
    
    tx = Transaction.new(
      amount: 100, 
      event_date: Date.today, 
      payment_date: Date.today,
      category: category, 
      user: user,
      description: 'Conflito de tipos',
      transaction_type: 'expense',
      installment_plan: installment_plan, 
      recurring_commitment: recurring_commitment
    )
    tx.entries.build([
      { account_id: account.id, entry_type: 'debit', amount: 100 },
      { account_id: expense_account.id, entry_type: 'credit', amount: 100 }
    ])
    
    expect(tx).not_to be_valid
    expect(tx.errors[:base]).to include("Transaction can only belong to one type: recurring commitment or installment plan")
  end

  it 'deduplicates identical transactions during import' do
    # Exemplo: simular importação duplicada
  end
end
