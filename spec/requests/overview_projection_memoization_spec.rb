require 'rails_helper'

RSpec.describe 'Overview recurring projection memoization', type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user
    # One active recurring commitment to ensure service returns something
    cat = create(:category, :expense, user: user)
    from_acc = create(:account, :asset, user: user)
    to_acc = create(:account, :expense_destination, user: user)
    create(:recurring_commitment, user: user, category: cat, from_account: from_acc, to_account: to_acc, start_date: Date.today.beginning_of_month, default_amount: 42.50, recurrence_frequency: 'monthly', status: :active, name: 'Gym')
  end

  it 'calls RecurringProjectionService only once per request context even if used twice' do
    expect(RecurringProjectionService).to receive(:call).once.and_call_original
    get overview_index_path
  end
end
