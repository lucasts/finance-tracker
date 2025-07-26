require 'rails_helper'

RSpec.describe RecurringTransactionsJob, type: :job do
  let!(:user) { create(:user) }
  let!(:category) { create(:category, user: user) }
  let!(:account) { create(:account, user: user) }
  let(:occurrence_date) { Date.current - 1.day }
  let!(:commitment) do
    create(:recurring_commitment, user: user, category: category, from_account: account, status: :active, start_date: occurrence_date - 1.month, end_date: nil, default_amount: 100)
  end

  before do
    allow_any_instance_of(RecurringCommitment).to receive(:next_occurrence_date).and_return(occurrence_date)
    allow_any_instance_of(RecurringCommitment).to receive(:active?).and_return(true)
  end

  it 'generates transaction for recurring commitments with next occurrence' do
    expect {
      described_class.perform_now
    }.to change { Transaction.count }.by(1)
  end

  it 'does not generate if transaction already exists for the date' do
    CreateTransactionService.call(
      description: commitment.name, 
      amount: 100, 
      event_date: occurrence_date, 
      payment_date: occurrence_date, 
      user: user, 
      category: category, 
      recurring_commitment: commitment, 
      transaction_type: 'expense',
      entries_attributes: [
        { account_id: create(:account, user: user).id, entry_type: 'debit', amount: 100 },
        { account_id: account.id, entry_type: 'credit', amount: 100 }
      ]
    )
    expect {
      described_class.perform_now
    }.not_to change { Transaction.count }
  end
end
