require 'rails_helper'

RSpec.describe OverviewController, type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe 'GET #index' do
    it 'renders dashboard' do
      get overview_index_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Dashboard Financeiro')
    end
  end
end
