require 'rails_helper'

RSpec.describe 'Transaction Edge Cases', type: :model do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }
  let(:category) { create(:category, user: user) }

  it 'creates transaction with extremely high value' do
    tx = Transaction.new(
      amount: 1_000_000_000, 
      event_date: Date.today, 
      payment_date: Date.today,
      from_account: account, 
      category: category, 
      user: user,
      description: 'Valor extremo',
      transaction_type: 'expense'
    )
    expect(tx).to be_valid
  end

  it 'creates transaction with extreme negative value' do
    tx = Transaction.new(
      amount: -1_000_000_000, 
      event_date: Date.today, 
      payment_date: Date.today,
      from_account: account, 
      category: category, 
      user: user,
      description: 'Valor negativo extremo',
      transaction_type: 'expense'
    )
    expect(tx).to be_valid
  end

  it 'creates transaction with very old date' do
    tx = Transaction.new(
      amount: 100, 
      event_date: Date.new(1900,1,1), 
      payment_date: Date.new(1900,1,1),
      from_account: account, 
      category: category, 
      user: user,
      description: 'Data antiga',
      transaction_type: 'expense'
    )
    expect(tx).to be_valid
  end

  it 'creates transaction with very future date' do
    tx = Transaction.new(
      amount: 100, 
      event_date: Date.new(2099,12,31), 
      payment_date: Date.new(2099,12,31),
      from_account: account, 
      category: category, 
      user: user,
      description: 'Data futura',
      transaction_type: 'expense'
    )
    expect(tx).to be_valid
  end

  it 'creates transaction with long description' do
    tx = Transaction.new(
      amount: 100, 
      event_date: Date.today, 
      payment_date: Date.today,
      from_account: account, 
      category: category, 
      user: user, 
      description: 'a'*500,
      transaction_type: 'expense'
    )
    expect(tx).to be_valid
  end

  it 'blocks transaction that is both installment and recurring' do
    installment_plan = create(:installment_plan, user: user)
    recurring_commitment = create(:recurring_commitment, user: user)
    
    tx = Transaction.new(
      amount: 100, 
      event_date: Date.today, 
      payment_date: Date.today,
      from_account: account, 
      category: category, 
      user: user,
      description: 'Conflito de tipos',
      transaction_type: 'expense',
      installment_plan: installment_plan, 
      recurring_commitment: recurring_commitment
    )
    expect(tx).not_to be_valid
    expect(tx.errors[:base]).to include("Transaction can only belong to one type: recurring commitment or installment plan")
  end

  it 'deduplicates identical transactions during import' do
    # Exemplo: simular importação duplicada
  end
end
