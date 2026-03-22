require 'rails_helper'

RSpec.describe GenerateInstallmentTransactionsJob, type: :job do
  let!(:user) { create(:user) }
  let!(:category) { create(:category, user: user) }
  let!(:account) { create(:account, user: user) }
  let!(:plan) do
    create(:installment_plan, user: user, category: category, status: :active, installment_count: 3)
  end

  it 'generates installment transaction for active plans with pending installments' do
    expect {
      described_class.perform_now
    }.to change(Transaction, :count).by(1)
  end

  it 'does not generate if all installments already exist' do
    3.times do |i|
      create(:transaction, :installment, user: user, category: category, installment_plan: plan, event_date: Date.current + i.months, transaction_type: 'expense', from_account: account)
    end
    expect {
      described_class.perform_now
    }.not_to change(Transaction, :count)
  end

  it 'returns errors if there is a failure' do
    allow(CreateTransactionService).to receive(:call).and_return(
      double(persisted?: false, errors: double(full_messages: double(to_sentence: 'Mocked failure')))
    )
    result = described_class.perform_now
    expect(result[:error_count]).to be > 0
  end
end
