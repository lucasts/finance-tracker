require 'rails_helper'

RSpec.describe 'Transactions', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:account) { create(:account, user: user) }
  let(:category) { create(:category, user: user) }
  let(:valid_params) { { transaction: { amount: 100, date: Date.today, account_id: account.id, category_id: category.id } } }

  context 'unauthorized access' do
    it 'redirects non-logged user' do
      get transactions_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  context 'multi-user filter' do
    it 'user only sees their own transactions' do
      # Example: create transaction from another user and ensure it doesn't appear
    end
  end

  context 'CRUD' do
    before { sign_in user }
    it 'creates, edits, deletes and views transaction' do
      # Example: complete CRUD flow
    end
  end
end
