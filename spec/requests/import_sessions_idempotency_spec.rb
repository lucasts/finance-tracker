require 'rails_helper'

RSpec.describe 'ImportSessions idempotency', type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, :asset, user: user) }

  before { sign_in user }

  def uploaded_file(path, filename: 'sample.ofx', type: 'application/octet-stream')
    Rack::Test::UploadedFile.new(path, type, original_filename: filename)
  end

  it 'does not duplicate imported transactions when same OFX file is imported again for same account' do
    file_path = Rails.root.join('spec/fixtures/files/sample.ofx')

    # First import
    post import_sessions_path, params: {
      import_session: {
        source_type: 'ofx',
        account_id: account.id,
        file: uploaded_file(file_path)
      }
    }
    expect(response).to redirect_to(import_session_path(ImportSession.last))
    first_session = ImportSession.last
    expect(first_session.imported_transactions.count).to eq(2)

    # Second import (same file) should redirect to reimport_summary of first session
    expect {
      post import_sessions_path, params: {
        import_session: {
          source_type: 'ofx',
          account_id: account.id,
          file: uploaded_file(file_path)
        }
      }
    }.not_to change(ImportSession, :count)
    expect(response).to redirect_to(reimport_summary_import_session_path(first_session))
  end
end
