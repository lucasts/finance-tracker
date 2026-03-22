require 'rails_helper'

RSpec.describe 'BatchProcessing', type: :request do
  let(:user) { create(:user) }
  let!(:account) { create(:account, user: user) }
  let!(:import_session) { create(:import_session, user: user, account: account) }

  before do
    create(:imported_transaction, import_session: import_session, line_number: 1, raw_data: '{}', amount: 100.0)
    create(:imported_transaction, import_session: import_session, line_number: 2, raw_data: '{}', amount: 200.0)
sign_in user
  end


  describe 'POST #batch_process_pending' do
    it 'processa todas as pendentes como ignore' do
      post batch_process_pending_import_session_path(import_session), params: { action_type: 'ignore' }, as: :json
      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data['success']).to be true
      expect(data['processed_count']).to eq(2)
    end
  end
end
