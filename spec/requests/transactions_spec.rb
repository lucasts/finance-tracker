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
      skip 'Full isolation coverage in transactions_controller_spec'
    end
  end

  context 'CRUD' do
    before { sign_in user }

    it 'creates, edits, deletes and views transaction' do
      skip 'Full CRUD coverage in transactions_controller_spec'
    end

    it 'creates an installment plan and ensures correct installment statuses' do
      bank_account = create(:account, :asset, user: user)
      expense_account = create(:account, :expense_destination, user: user)
      category = create(:category, :expense, user: user)

      params = {
        transaction: {
          transaction_type: 'expense',
          description: 'Compra parcelada spec',
          amount: 300.00,
          event_date: Date.current,
          payment_date: Date.current,
          from_account_id: bank_account.id,
          to_account_id: expense_account.id,
          category_id: category.id
        },
        create_installment_plan: 'true',
        installment_count: 3
      }

      post transactions_path, params: params
      expect(response).to redirect_to(transactions_path)

      transactions = Transaction.where("description LIKE ?", "%Compra parcelada spec%").order(:installment_number)
      expect(transactions.count).to eq(3)
      expect(transactions.first.status).to eq('confirmed')
      expect(transactions.second.status).to eq('pending')
      expect(transactions.third.status).to eq('pending')
    end
  end
end
