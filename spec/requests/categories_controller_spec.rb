require 'rails_helper'

RSpec.describe CategoriesController, type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  before { sign_in user }

  describe 'security and authorization' do
    context 'unauthorized access' do
      before { sign_out user }

      it 'redirects unauthenticated users to sign in' do
        get categories_path
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'prevents access to category creation' do
        post categories_path, params: { category: attributes_for(:category) }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'user data isolation' do
      let!(:user_category) { create(:category, user: user, name: 'User Category') }
      let!(:other_user_category) { create(:category, user: other_user, name: 'Other Category') }

      it 'only shows current user categories' do
        get categories_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include(user_category.name)
        expect(response.body).not_to include(other_user_category.name)
      end

      it 'prevents editing other users categories' do
        get edit_category_path(other_user_category)
        expect(response).to have_http_status(:not_found)
      end

      it 'prevents updating other users categories' do
        patch category_path(other_user_category), params: {
          category: { name: 'Hacked Category' }
        }
        expect(response).to have_http_status(:not_found)
      end

      it 'prevents deleting other users categories' do
        delete category_path(other_user_category)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET #index' do
    let(:food_category) { create(:category, user: user, name: 'Alimentação') }
    let(:transport_category) { create(:category, user: user, name: 'Transporte') }

    before { food_category; transport_category }

    it 'returns success' do
      get categories_path
      expect(response).to have_http_status(:success)
    end

    it 'shows all user categories' do
      get categories_path
      expect(response.body).to include('Alimentação')
      expect(response.body).to include('Transporte')
    end
  end

  describe 'GET #new' do
    it 'returns success' do
      get new_category_path
      expect(response).to have_http_status(:success)
    end

    it 'builds new category for current user' do
      get new_category_path
      category = assigns(:category)
      expect(category).to be_a_new(Category)
      expect(category.user).to eq(user)
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        category: {
          name: 'Nova Categoria',
          description: 'Descrição da categoria'
        }
      }
    end

    context 'with valid parameters' do
      it 'creates a new category' do
        expect {
          post categories_path, params: valid_params
        }.to change(Category, :count).by(1)
      end

      it 'associates category with current user' do
        post categories_path, params: valid_params
        category = Category.last
        expect(category.user).to eq(user)
        expect(category.name).to eq('Nova Categoria')
      end

      it 'redirects to categories index with success notice' do
        post categories_path, params: valid_params
        expect(response).to redirect_to(categories_path)
        expect(flash[:notice]).to include('sucesso')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        { category: { name: '', description: 'Sem nome' } }
      end

      it 'does not create a category' do
        expect {
          post categories_path, params: invalid_params
        }.not_to change(Category, :count)
      end

      it 'renders new template with errors' do
        post categories_path, params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'duplicate names' do
      before { create(:category, user: user, name: 'Duplicada') }

      it 'prevents duplicate category names for same user' do
        duplicate_params = { category: { name: 'Duplicada' } }

        expect {
          post categories_path, params: duplicate_params
        }.not_to change(Category, :count)
      end

      it 'allows same name for different users' do
        other_user_category = create(:category, user: other_user, name: 'Mesma Categoria')
        same_name_params = { category: { name: 'Mesma Categoria' } }

        expect {
          post categories_path, params: same_name_params
        }.to change(Category, :count).by(1)
      end
    end

    context 'SQL injection prevention' do
      let(:malicious_params) do
        {
          category: {
            name: "'; DROP TABLE categories; --",
            description: 'Malicious description'
          }
        }
      end

      it 'safely handles malicious input' do
        expect {
          post categories_path, params: malicious_params
        }.to change(Category, :count).by(1)

        category = Category.last
        expect(category.name).to eq("'; DROP TABLE categories; --")
        expect(Category.count).to be > 0 # Table should still exist
      end
    end
  end

  describe 'GET #edit' do
    let(:category) { create(:category, user: user) }

    it 'returns success' do
      get edit_category_path(category)
      expect(response).to have_http_status(:success)
    end

    it 'assigns the correct category' do
      get edit_category_path(category)
      expect(assigns(:category)).to eq(category)
    end
  end

  describe 'PATCH #update' do
    let(:category) { create(:category, user: user, name: 'Nome Original') }
    let(:update_params) do
      {
        category: {
          name: 'Nome Atualizado'
        }
      }
    end

    context 'with valid parameters' do
      it 'updates the category' do
        patch category_path(category), params: update_params
        category.reload
        expect(category.name).to eq('Nome Atualizado')
      end

      it 'redirects to categories index with success notice' do
        patch category_path(category), params: update_params
        expect(response).to redirect_to(categories_path)
        expect(flash[:notice]).to include('sucesso')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        { category: { name: '' } }
      end

      it 'does not update the category' do
        original_name = category.name
        patch category_path(category), params: invalid_params
        category.reload
        expect(category.name).to eq(original_name)
      end

      it 'renders edit template with errors' do
        patch category_path(category), params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:category) { create(:category, user: user) }

    it 'destroys the category' do
      expect {
        delete category_path(category)
      }.to change(Category, :count).by(-1)
    end

    it 'redirects to categories index with success notice' do
      delete category_path(category)
      expect(response).to redirect_to(categories_path)
      expect(flash[:notice]).to include('sucesso')
    end

    context 'with associated transactions' do
      let!(:transaction) { create(:transaction, :confirmed, user: user, category: category) }

      it 'handles dependent destroy properly' do
        expect {
          delete category_path(category)
        }.not_to change(Category, :count)

        expect(response).to redirect_to(categories_path)
        expect(flash[:alert]).to include('não pode ser removida')
        expect(Transaction).to exist(transaction.id)
      end
    end
  end

  describe 'parameter security' do
    let(:category) { create(:category, user: user) }

    it 'only permits safe parameters' do
      malicious_params = {
        category: {
          name: 'Safe Name',
          description: 'Safe Description',
          user_id: other_user.id, # Should be ignored
          id: 999, # Should be ignored
          created_at: Time.current # Should be ignored
        }
      }

      post categories_path, params: malicious_params

      created_category = Category.last
      expect(created_category.user).to eq(user) # Not other_user
      expect(created_category.name).to eq('Safe Name')
    end

    it 'prevents mass assignment attacks' do
      patch category_path(category), params: {
        category: {
          name: 'Updated Name',
          user_id: other_user.id # Attempt to change ownership
        }
      }

      category.reload
      expect(category.user).to eq(user) # Should remain unchanged
      expect(category.name).to eq('Updated Name') # Safe parameter should update
    end
  end

  describe 'edge cases' do
    it 'handles very long category names' do
      long_name = 'A' * 300
      long_params = { category: { name: long_name } }

      post categories_path, params: long_params

      if Category.last
        expect(Category.last.name.length).to be <= 255 # Assuming DB limit
      end
    end

    it 'handles special characters in names' do
      special_params = {
        category: {
          name: 'Categoria com àçêntos & símbolos 123!@#',
          description: 'Тест кириллица 測試中文'
        }
      }

      expect {
        post categories_path, params: special_params
      }.to change(Category, :count).by(1)

      category = Category.last
      expect(category.name).to eq('Categoria com àçêntos & símbolos 123!@#')
    end

    it 'handles concurrent category creation' do
      # Simulate race condition
      allow_any_instance_of(Category).to receive(:save).and_return(false)

      post categories_path, params: {
        category: { name: 'Test Category' }
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
