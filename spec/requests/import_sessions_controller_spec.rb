require 'rails_helper'

RSpec.describe ImportSessionsController, type: :request do
  let(:user) { create(:user) }
  let!(:account) { create(:account, user: user) }

  before { sign_in user }

  describe 'GET #index' do
    it 'returns success' do
      get import_sessions_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET #show' do
    let!(:session) { create(:import_session, user: user, account: account) }
    it 'returns success' do
      get import_session_path(session)
      expect(response).to have_http_status(:ok)
    end
  end
end
