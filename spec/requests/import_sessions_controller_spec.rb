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

  describe 'GET #reimport_summary' do
    let!(:session) { create(:import_session, user: user, account: account) }

    it 'returns success for the session owner' do
      get reimport_summary_import_session_path(session)
      expect(response).to have_http_status(:ok)
    end

    it 'displays the original filename' do
      get reimport_summary_import_session_path(session)
      expect(response.body).to include(session.original_filename)
    end

    it 'displays the account name' do
      get reimport_summary_import_session_path(session)
      expect(response.body).to include(session.account.name)
    end

    it 'denies access to a different user' do
      other_user = create(:user)
      sign_in other_user
      get reimport_summary_import_session_path(session)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create — duplicate file (reimport)' do
    it 'redirects to reimport_summary when same file is uploaded again' do
      # First upload: creates the original session
      post import_sessions_path, params: {
        import_session: {
          file: fixture_file_upload('spec/fixtures/files/import_example.csv', 'text/csv'),
          source_type: 'csv',
          account_id: account.id
        }
      }
      original_session = ImportSession.last

      # Second upload: same file → must redirect to reimport_summary
      post import_sessions_path, params: {
        import_session: {
          file: fixture_file_upload('spec/fixtures/files/import_example.csv', 'text/csv'),
          source_type: 'csv',
          account_id: account.id
        }
      }

      expect(response).to redirect_to(reimport_summary_import_session_path(original_session))
    end
  end
end
