require 'rails_helper'

RSpec.describe GenerateRecurringTransactionsJob, type: :job do
  describe '#perform' do
    context 'with active recurring commitments' do
      let!(:user) { create(:user) }
      let!(:from_account) { create(:account, user: user) }
      let!(:to_account) { create(:account, user: user) }
      let!(:category) { create(:category, user: user) }
      let!(:recurring_commitment) do
        create(:recurring_commitment,
               user: user,
               category: category,
               start_date: 1.month.ago,
               from_account: from_account,
               to_account: to_account,
               default_amount: 100)
      end

      it 'generates transactions for active recurring commitments' do
        expect {
          described_class.perform_now
        }.to change { Transaction.count }.by(1)
      end

      it 'does not generate transaction if one already exists for the date' do
        CreateTransactionService.call(
          description: recurring_commitment.name, 
          amount: 100, 
          event_date: Date.current, 
          payment_date: Date.current, 
          user: user, 
          category: category, 
          recurring_commitment: recurring_commitment, 
          transaction_type: 'expense',
          recurrence_type: 'recurring',
          entries_attributes: [
            { account_id: to_account.id, entry_type: 'debit', amount: 100 },
            { account_id: from_account.id, entry_type: 'credit', amount: 100 }
          ]
        )
        
        expect {
          described_class.perform_now
        }.not_to change { Transaction.count }
      end

      it 'returns errors if there is a failure' do
        allow(CreateTransactionService).to receive(:call).and_return(
          double(persisted?: false, errors: double(full_messages: double(to_sentence: 'Mocked failure')))
        )
        result = described_class.perform_now
        expect(result[:error_count]).to be > 0
      end
    end
  end
end
