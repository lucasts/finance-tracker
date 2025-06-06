require 'rails_helper'

RSpec.describe AccountsController, type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:account_type) { create(:account_type) }

  before { sign_in user }

  describe 'security and authorization' do
    context 'unauthorized access' do
      before { sign_out user }

      it 'redirects unauthenticated users to sign in' do
        get accounts_path
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'prevents access to account creation' do
        post accounts_path, params: { account: attributes_for(:account) }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'user data isolation' do
      let!(:user_account) { create(:account, user: user) }
      let!(:other_user_account) { create(:account, user: other_user) }

      it 'only shows current user accounts' do
        get accounts_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include(user_account.name)
        expect(response.body).not_to include(other_user_account.name)
      end

      it 'prevents editing other users accounts' do
        get edit_account_path(other_user_account)
        expect(response).to have_http_status(:not_found)
      end

      it 'prevents updating other users accounts' do
        patch account_path(other_user_account), params: { 
          account: { name: 'Hacked Account' } 
        }
        expect(response).to have_http_status(:not_found)
      end

      it 'prevents deleting other users accounts' do
        delete account_path(other_user_account)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET #index' do
    let!(:checking_account) { create(:account, user: user, name: 'Checking') }
    let!(:savings_account) { create(:account, user: user, name: 'Savings') }

    it 'returns success' do
      get accounts_path
      expect(response).to have_http_status(:success)
    end

    it 'shows all user accounts ordered by name' do
      get accounts_path
      expect(response.body).to include('Checking')
      expect(response.body).to include('Savings')
      
      # Should be ordered alphabetically
      checking_pos = response.body.index('Checking')
      savings_pos = response.body.index('Savings')
      expect(checking_pos).to be < savings_pos
    end

    it 'includes account type information' do
      get accounts_path
      # Use uma regex para encontrar o account type escapado ou não
      account_type_pattern = Regexp.escape(checking_account.account_type.name).gsub('&', '(&amp;|&)')
      expect(response.body).to match(/#{account_type_pattern}/)
    end
  end

  describe 'GET #new' do
    it 'returns success' do
      get new_account_path
      expect(response).to have_http_status(:success)
    end

    it 'builds new account for current user' do
      get new_account_path
      account = assigns(:account)
      expect(account).to be_a_new(Account)
      expect(account.user).to eq(user)
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        account: {
          name: 'Test Account',
          account_type_id: account_type.id
        }
      }
    end

    context 'with valid parameters' do
      it 'creates a new account' do
        expect {
          post accounts_path, params: valid_params
        }.to change(Account, :count).by(1)
      end

      it 'associates account with current user' do
        post accounts_path, params: valid_params
        account = Account.last
        expect(account.user).to eq(user)
        expect(account.name).to eq('Test Account')
      end

      it 'redirects to accounts index with success notice' do
        post accounts_path, params: valid_params
        expect(response).to redirect_to(accounts_path)
        expect(flash[:notice]).to eq('Conta criada com sucesso.')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        { account: { name: '', account_type_id: account_type.id } }
      end

      it 'does not create an account' do
        expect {
          post accounts_path, params: invalid_params
        }.not_to change(Account, :count)
      end

      it 'renders new template with errors' do
        post accounts_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'SQL injection prevention' do
      let(:malicious_params) do
        {
          account: {
            name: "'; DROP TABLE accounts; --",
            account_type_id: account_type.id
          }
        }
      end

      it 'safely handles malicious input' do
        expect {
          post accounts_path, params: malicious_params
        }.to change(Account, :count).by(1)
        
        account = Account.last
        expect(account.name).to eq("'; DROP TABLE accounts; --")
        expect(Account.count).to be > 0 # Table should still exist
      end
    end
  end

  describe 'GET #edit' do
    let(:account) { create(:account, user: user) }

    it 'returns success' do
      get edit_account_path(account)
      expect(response).to have_http_status(:success)
    end

    it 'assigns the correct account' do
      get edit_account_path(account)
      expect(assigns(:account)).to eq(account)
    end
  end

  describe 'PATCH #update' do
    let(:account) { create(:account, user: user, name: 'Original Name') }
    let(:update_params) do
      {
        account: {
          name: 'Updated Name'
        }
      }
    end

    context 'with valid parameters' do
      it 'updates the account' do
        patch account_path(account), params: update_params
        account.reload
        expect(account.name).to eq('Updated Name')
      end

      it 'redirects to accounts index with success notice' do
        patch account_path(account), params: update_params
        expect(response).to redirect_to(accounts_path)
        expect(flash[:notice]).to eq('Conta atualizada com sucesso.')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        { account: { name: '' } }
      end

      it 'does not update the account' do
        original_name = account.name
        patch account_path(account), params: invalid_params
        account.reload
        expect(account.name).to eq(original_name)
      end

      it 'renders edit template with errors' do
        patch account_path(account), params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:account) { create(:account, user: user) }

    it 'destroys the account' do
      expect {
        delete account_path(account)
      }.to change(Account, :count).by(-1)
    end

    it 'redirects to accounts index with success notice' do
      delete account_path(account)
      expect(response).to redirect_to(accounts_path)
      expect(flash[:notice]).to eq('Conta removida com sucesso.')
    end

    context 'with associated transactions' do
      let!(:transaction) { create(:transaction, :confirmed, user: user, from_account: account) }

      it 'handles dependent destroy properly' do
        expect {
          delete account_path(account)
        }.not_to change(Account, :count)
        
        expect(response).to redirect_to(accounts_path)
        expect(flash[:alert]).to include('não pode ser removida')
        expect(Transaction.exists?(transaction.id)).to be_truthy
      end
    end
  end

  describe 'parameter security' do
    let(:account) { create(:account, user: user) }

    it 'only permits safe parameters' do
      malicious_params = {
        account: {
          name: 'Safe Name',
          account_type_id: account_type.id,
          user_id: other_user.id, # Should be ignored
          id: 999, # Should be ignored
          created_at: Time.current, # Should be ignored
        }
      }

      post accounts_path, params: malicious_params
      
      created_account = Account.last
      expect(created_account.user).to eq(user) # Not other_user
      expect(created_account.name).to eq('Safe Name')
    end

    it 'prevents mass assignment attacks' do
      patch account_path(account), params: {
        account: {
          name: 'Updated Name',
          user_id: other_user.id # Attempt to change ownership
        }
      }

      account.reload
      expect(account.user).to eq(user) # Should remain unchanged
      expect(account.name).to eq('Updated Name') # Safe parameter should update
    end
  end

  describe 'edge cases' do
    it 'handles non-existent account_type gracefully' do
      invalid_params = {
        account: {
          name: 'Test Account',
          account_type_id: 99999 # Non-existent ID
        }
      }

      expect {
        post accounts_path, params: invalid_params
      }.not_to change(Account, :count)
    end

    it 'handles concurrent account creation' do
      # Simulate race condition
      allow_any_instance_of(Account).to receive(:save).and_return(false)
      
      post accounts_path, params: {
        account: { name: 'Test', account_type_id: account_type.id }
      }
      
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
