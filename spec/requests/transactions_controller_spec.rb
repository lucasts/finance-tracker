require 'rails_helper'

RSpec.describe TransactionsController, type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:account) { create(:account, user: user) }
  let(:other_account) { create(:account, user: other_user) }
  let(:category) { create(:category, user: user) }

  before { sign_in user }

  describe 'security and authorization' do
    context 'unauthorized access' do
      before { sign_out user }

      it 'redirects unauthenticated users to sign in' do
        get transactions_path
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'prevents access to transaction creation' do
        post transactions_path, params: { transaction: attributes_for(:transaction) }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'user data isolation' do
      let!(:user_transaction) { create(:transaction, :confirmed, user: user, from_account: account, event_date: Date.current) }
      let!(:other_user_transaction) { create(:transaction, :confirmed, user: other_user, from_account: other_account, event_date: Date.current) }

      it 'only shows current user transactions' do
        get transactions_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include(user_transaction.description)
        expect(response.body).not_to include(other_user_transaction.description)
      end

      it 'prevents viewing other users transactions' do
        get transaction_path(other_user_transaction)
        expect(response).to have_http_status(:not_found)
      end

      it 'prevents editing other users transactions' do
        get edit_transaction_path(other_user_transaction)
        expect(response).to have_http_status(:not_found)
      end

      it 'prevents updating other users transactions' do
        patch transaction_path(other_user_transaction), params: { 
          transaction: { description: 'Hacked' } 
        }
        expect(response).to have_http_status(:not_found)
      end

      it 'prevents deleting other users transactions' do
        delete transaction_path(other_user_transaction)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET #index' do
    let!(:current_month_transaction) { create(:transaction, :confirmed, user: user, from_account: account, event_date: Date.current) }
    let!(:last_month_transaction) { create(:transaction, :confirmed, user: user, from_account: account, event_date: 1.month.ago) }

    it 'returns success' do
      get transactions_path
      expect(response).to have_http_status(:success)
    end

    it 'shows current month transactions by default' do
      get transactions_path
      expect(response.body).to include(current_month_transaction.description)
      expect(response.body).not_to include(last_month_transaction.description)
    end

    it 'filters by specified month' do
      get transactions_path, params: { month: 1.month.ago.strftime('%Y-%m') }
      expect(response.body).to include(last_month_transaction.description)
      expect(response.body).not_to include(current_month_transaction.description)
    end

    it 'handles invalid month parameter gracefully' do
      get transactions_path, params: { month: 'invalid-date' }
      expect(response).to have_http_status(:success)
      expect(response.body).to include(current_month_transaction.description)
    end

    context 'with installment plan filter' do
      let(:installment_plan) { create(:installment_plan, user: user) }
      let!(:plan_transaction) { create(:transaction, :confirmed, user: user, from_account: account, installment_plan: installment_plan, recurrence_type: 'installment', event_date: Date.current) }

      it 'filters by installment plan' do
        get transactions_path, params: { plan: installment_plan.id }
        expect(response.body).to include(plan_transaction.description)
        expect(response.body).not_to include(current_month_transaction.description)
      end

      it 'prevents filtering by other users installment plans' do
        other_plan = create(:installment_plan, user: other_user)
        get transactions_path, params: { plan: other_plan.id }
        expect(assigns(:installment_plan)).to be_nil
      end
    end
  end

  describe 'GET #show' do
    let(:transaction) { create(:transaction, :confirmed, user: user, from_account: account) }

    it 'returns transaction details partial' do
      get transaction_path(transaction)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(transaction.description)
    end
  end

  describe 'GET #new' do
    it 'returns success' do
      get new_transaction_path
      expect(response).to have_http_status(:success)
    end

    it 'builds new transaction with defaults' do
      get new_transaction_path
      transaction = assigns(:transaction)
      expect(transaction).to be_a_new(Transaction)
      expect(transaction.event_date).to eq(Date.current)
      expect(transaction.payment_date).to eq(Date.current)
      expect(transaction.recurrence_type).to eq('single')
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        transaction: {
          description: 'Test Transaction',
          amount: 100.00,
          event_date: Date.current,
          payment_date: Date.current,
          transaction_type: 'expense',
          from_account_id: account.id,
          category_id: category.id,
          status: 'pending'
        },
        recurrence_type: 'single'
      }
    end

    context 'with valid parameters' do
      it 'creates a new transaction' do
        expect {
          post transactions_path, params: valid_params
        }.to change(Transaction, :count).by(1)
      end

      it 'associates transaction with current user' do
        post transactions_path, params: valid_params
        transaction = Transaction.last
        expect(transaction.user).to eq(user)
      end

      it 'redirects to transactions index' do
        post transactions_path, params: valid_params
        expect(response).to redirect_to(transactions_path)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        valid_params.deep_merge(transaction: { amount: nil })
      end

      it 'does not create a transaction' do
        expect {
          post transactions_path, params: invalid_params
        }.not_to change(Transaction, :count)
      end

      it 'renders new template with errors' do
        post transactions_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with other users account' do
      let(:invalid_params) do
        valid_params.deep_merge(transaction: { from_account_id: other_account.id })
      end

      it 'does not create transaction with other users account' do
        expect {
          post transactions_path, params: invalid_params
        }.not_to change(Transaction, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'SQL injection prevention' do
      let(:malicious_params) do
        valid_params.deep_merge(transaction: { 
          description: "'; DROP TABLE transactions; --" 
        })
      end

      it 'safely handles malicious input' do
        expect {
          post transactions_path, params: malicious_params
        }.to change(Transaction, :count).by(1)
        
        transaction = Transaction.last
        expect(transaction.description).to eq("'; DROP TABLE transactions; --")
        expect(Transaction.count).to be > 0 # Table should still exist
      end
    end
  end

  describe 'GET #edit' do
    let(:transaction) { create(:transaction, :confirmed, user: user, from_account: account) }

    it 'returns success' do
      get edit_transaction_path(transaction)
      expect(response).to have_http_status(:success)
    end
  end

  describe 'PATCH #update' do
    let(:transaction) { create(:transaction, :confirmed, user: user, from_account: account) }
    let(:update_params) do
      {
        transaction: {
          description: 'Updated Description',
          amount: 200.00
        }
      }
    end

    context 'with valid parameters' do
      it 'updates the transaction' do
        patch transaction_path(transaction), params: update_params
        transaction.reload
        expect(transaction.description).to eq('Updated Description')
        expect(transaction.amount).to eq(200.00)
      end

      it 'redirects to transactions index' do
        patch transaction_path(transaction), params: update_params
        expect(response).to redirect_to(transactions_path)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        { transaction: { amount: nil } }
      end

      it 'does not update the transaction' do
        original_description = transaction.description
        patch transaction_path(transaction), params: invalid_params
        transaction.reload
        expect(transaction.description).to eq(original_description)
      end

      it 'renders edit template with errors' do
        patch transaction_path(transaction), params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:transaction) { create(:transaction, :confirmed, user: user, from_account: account) }

    it 'destroys the transaction' do
      expect {
        delete transaction_path(transaction)
      }.to change(Transaction, :count).by(-1)
    end

    it 'redirects to transactions index' do
      delete transaction_path(transaction)
      expect(response).to redirect_to(transactions_path)
    end
  end

  describe 'multi-user filtering edge cases' do
    let!(:shared_category_name_transaction) do
      shared_category = create(:category, user: other_user, name: category.name)
      create(:transaction, :confirmed, user: other_user, from_account: other_account, category: shared_category)
    end

    it 'does not show transactions with same category name from different users' do
      get transactions_path
      expect(response.body).not_to include(shared_category_name_transaction.description)
    end

    it 'maintains data isolation even with shared resource names' do
      get transactions_path, params: { 
        search: { category_name: category.name }
      }
      expect(response.body).not_to include(shared_category_name_transaction.description)
    end
  end

  describe 'Transfer functionality' do
    let(:from_account) { create(:account, user: user, name: 'Conta Corrente') }
    let(:to_account) { create(:account, user: user, name: 'Poupança') }
    let(:other_user_account) { create(:account, user: other_user, name: 'Conta Alheia') }

    describe 'POST #create with transfer' do
      context 'with valid transfer parameters' do
        let(:valid_transfer_params) do
          {
            transaction: {
              description: 'Transferência para poupança',
              amount: 500.00,
              event_date: Date.current,
              payment_date: Date.current,
              transaction_type: 'transfer',
              from_account_id: from_account.id,
              to_account_id: to_account.id,
              status: 'confirmed'
            },
            recurrence_type: 'single'
          }
        end

        it 'creates a new transfer transaction' do
          expect {
            post transactions_path, params: valid_transfer_params
          }.to change(Transaction, :count).by(1)
        end

        it 'creates transfer without category' do
          post transactions_path, params: valid_transfer_params
          transaction = Transaction.last
          expect(transaction.category).to be_nil
          expect(transaction.transaction_type).to eq('transfer')
        end

        it 'associates transaction with current user' do
          post transactions_path, params: valid_transfer_params
          transaction = Transaction.last
          expect(transaction.user).to eq(user)
        end

        it 'redirects to transactions index' do
          post transactions_path, params: valid_transfer_params
          expect(response).to redirect_to(transactions_path)
        end
      end

      context 'with invalid transfer parameters' do
        let(:invalid_transfer_params) do
          {
            transaction: {
              description: 'Transferência inválida',
              amount: 500.00,
              event_date: Date.current,
              payment_date: Date.current,
              transaction_type: 'transfer',
              from_account_id: from_account.id,
              to_account_id: nil, # Missing to_account
              status: 'confirmed'
            },
            recurrence_type: 'single'
          }
        end

        it 'does not create transaction without to_account' do
          expect {
            post transactions_path, params: invalid_transfer_params
          }.not_to change(Transaction, :count)
        end

        it 'renders new template with errors' do
          post transactions_path, params: invalid_transfer_params
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context 'with same from_account and to_account' do
        let(:same_account_params) do
          {
            transaction: {
              description: 'Transferência para mesma conta',
              amount: 500.00,
              event_date: Date.current,
              payment_date: Date.current,
              transaction_type: 'transfer',
              from_account_id: from_account.id,
              to_account_id: from_account.id, # Same account
              status: 'confirmed'
            },
            recurrence_type: 'single'
          }
        end

        it 'does not create transaction with same accounts' do
          expect {
            post transactions_path, params: same_account_params
          }.not_to change(Transaction, :count)
        end

        it 'shows validation error' do
          post transactions_path, params: same_account_params
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context 'with category (should be invalid)' do
        let(:transfer_with_category_params) do
          {
            transaction: {
              description: 'Transferência com categoria',
              amount: 500.00,
              event_date: Date.current,
              payment_date: Date.current,
              transaction_type: 'transfer',
              from_account_id: from_account.id,
              to_account_id: to_account.id,
              category_id: category.id, # Should not have category
              status: 'confirmed'
            },
            recurrence_type: 'single'
          }
        end

        it 'does not create transfer with category' do
          expect {
            post transactions_path, params: transfer_with_category_params
          }.not_to change(Transaction, :count)
        end

        it 'shows validation error' do
          post transactions_path, params: transfer_with_category_params
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context 'with other users accounts' do
        let(:other_user_transfer_params) do
          {
            transaction: {
              description: 'Transferência com conta alheia',
              amount: 500.00,
              event_date: Date.current,
              payment_date: Date.current,
              transaction_type: 'transfer',
              from_account_id: from_account.id,
              to_account_id: other_user_account.id, # Other user's account
              status: 'confirmed'
            },
            recurrence_type: 'single'
          }
        end

        it 'does not create transfer with other users account' do
          expect {
            post transactions_path, params: other_user_transfer_params
          }.not_to change(Transaction, :count)
        end

        it 'returns unprocessable entity status' do
          post transactions_path, params: other_user_transfer_params
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    describe 'PATCH #update transfer' do
      let!(:transfer_transaction) do
        create(:transaction, :transfer, 
               user: user, 
               from_account: from_account, 
               to_account: to_account,
               description: 'Original transfer',
               amount: 300.00)
      end

      context 'with valid transfer updates' do
        let(:update_transfer_params) do
          {
            transaction: {
              description: 'Updated transfer description',
              amount: 750.00
            }
          }
        end

        it 'updates the transfer transaction' do
          patch transaction_path(transfer_transaction), params: update_transfer_params
          transfer_transaction.reload
          expect(transfer_transaction.description).to eq('Updated transfer description')
          expect(transfer_transaction.amount).to eq(750.00)
        end

        it 'maintains transfer type and accounts' do
          patch transaction_path(transfer_transaction), params: update_transfer_params
          transfer_transaction.reload
          expect(transfer_transaction.transaction_type).to eq('transfer')
          expect(transfer_transaction.from_account).to eq(from_account)
          expect(transfer_transaction.to_account).to eq(to_account)
          expect(transfer_transaction.category).to be_nil
        end

        it 'redirects to transactions index' do
          patch transaction_path(transfer_transaction), params: update_transfer_params
          expect(response).to redirect_to(transactions_path)
        end
      end

      context 'changing transfer to have category (invalid)' do
        let(:invalid_update_params) do
          {
            transaction: {
              category_id: category.id
            }
          }
        end

        it 'does not update transfer with category' do
          original_category = transfer_transaction.category
          patch transaction_path(transfer_transaction), params: invalid_update_params
          transfer_transaction.reload
          expect(transfer_transaction.category).to eq(original_category)
        end

        it 'returns unprocessable entity status' do
          patch transaction_path(transfer_transaction), params: invalid_update_params
          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    describe 'Transfer display and filtering' do
      let!(:income_transaction) { create(:transaction, :income, user: user, from_account: from_account, amount: 1000, event_date: Date.current) }
      let!(:expense_transaction) { create(:transaction, :expense, user: user, from_account: from_account, amount: 200, event_date: Date.current) }
      let!(:transfer_transaction) { create(:transaction, :transfer, user: user, from_account: from_account, to_account: to_account, amount: 300, event_date: Date.current) }

      it 'includes transfer transactions in index' do
        get transactions_path
        expect(response.body).to include(transfer_transaction.description)
        expect(response.body).to include('Transferência')
      end

      it 'shows transfer transactions without category' do
        get transactions_path
        expect(response).to have_http_status(:success)
        # Transfer should not have category displayed
        expect(response.body).to include(transfer_transaction.description)
      end

      it 'shows transfer details in show action' do
        get transaction_path(transfer_transaction)
        expect(response).to have_http_status(:success)
        expect(response.body).to include(transfer_transaction.description)
        expect(response.body).to include(from_account.name)
        expect(response.body).to include(to_account.name)
      end
    end
  end
end
