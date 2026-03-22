require 'rails_helper'

RSpec.describe AutomationJob, type: :job do
  let(:user) { create(:user) }
  let(:category) { create(:category, user: user) }
  let(:from_account) { create(:account, user: user) }
  let(:to_account) { create(:account, user: user) }
  let(:commitment) { create(:recurring_commitment, user: user, category: category, status: :active, start_date: Date.current - 1.month, from_account: from_account, to_account: to_account) }
  let(:plan) { create(:installment_plan, user: user, category: category, status: :active, installment_count: 2) }

  before { commitment; plan }

  it 'executes both jobs and returns count of generated transactions' do
    result = described_class.perform_now([ 'recurring', 'installments' ], Date.current)
    expect(result[:recurring_transactions]).to be >= 0
    expect(result[:installment_transactions]).to be >= 0
    expect(result[:errors]).to eq([])
  end

  it 'executes only recurring if requested' do
    result = described_class.perform_now([ 'recurring' ], Date.current)
    expect(result[:recurring_transactions]).to be >= 0
    expect(result[:installment_transactions]).to eq(0)
  end

  it 'executes only installments if requested' do
    result = described_class.perform_now([ 'installments' ], Date.current)
    expect(result[:installment_transactions]).to be >= 0
    expect(result[:recurring_transactions]).to eq(0)
  end

  it 'returns error if any job fails' do
    allow_any_instance_of(GenerateRecurringTransactionsJob).to receive(:perform).and_raise(StandardError, 'Simulated error')
    result = described_class.perform_now([ 'recurring' ], Date.current)
    expect(result[:errors]).not_to be_empty
  end
end
