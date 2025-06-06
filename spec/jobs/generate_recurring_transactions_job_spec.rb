require 'rails_helper'

RSpec.describe GenerateRecurringTransactionsJob, type: :job do
  let!(:user) { create(:user) }
  let!(:category) { create(:category, user: user) }
  let!(:account) { create(:account, user: user) }
  let!(:commitment) do
    create(:recurring_commitment, user: user, category: category, status: :active, start_date: Date.current - 1.month, end_date: nil)
  end

  it 'generates transactions for active recurring commitments' do
    expect {
      described_class.perform_now(Date.current)
    }.to change { Transaction.count }.by(1)
  end

  it 'does not generate transaction if one already exists for the date' do
    Transaction.create!(description: commitment.name, amount: 100, event_date: Date.current, payment_date: Date.current, user: user, category: category, from_account: account, recurring_commitment: commitment, transaction_type: 'expense', recurrence_type: 'recurring')
    expect {
      described_class.perform_now(Date.current)
    }.not_to change { Transaction.count }
  end

  it 'returns errors if there is a failure' do
    allow_any_instance_of(RecurringCommitment).to receive(:transactions).and_raise(StandardError, 'Simulated error')
    result = described_class.perform_now(Date.current)
    expect(result[:errors]).not_to be_empty
  end
end
