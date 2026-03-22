require 'rails_helper'

# Step 1: failing spec for partial duplicate with tolerance (date +/- 1 day, amount diff <= 0.01)
RSpec.describe 'ImportSessions advanced dedup', type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, :asset, user: user) }

  before { sign_in user }

  def upload_csv(lines, filename: 'partial.csv')
    content = lines.join("\n") + "\n"
    file = Tempfile.new('csv')
    file.write(content)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, 'text/csv', original_filename: filename)
  end

  it 'imports only the truly new line when second CSV file has near-duplicate (date +1 day, amount +0.01) expected to be deduped' do
    base_csv = [
      'data,valor,descricao',
      '2025-01-05,-100.00,Desc A',
      '2025-01-06,-50.00,Desc B'
    ]
    post import_sessions_path, params: { import_session: { source_type: 'csv', account_id: account.id, file: upload_csv(base_csv, filename: 'first.csv') } }
    expect(response).to have_http_status(:redirect)
    first_session = ImportSession.last
    expect(first_session.imported_transactions.count).to eq(2)

    # Near-duplicate of Desc A (date shift +1 day, amount difference 0.01) should be treated as duplicate under new heuristic
    second_csv = [
      'data,valor,descricao',
      '2025-01-06,-100.01,Desc A', # near duplicate of 2025-01-05 -100.00 Desc A
      '2025-01-07,-75.00,Desc C'   # new
    ]
    expect {
      post import_sessions_path, params: { import_session: { source_type: 'csv', account_id: account.id, file: upload_csv(second_csv, filename: 'second.csv') } }
    }.to change(ImportSession, :count).by(1)

    second_session = ImportSession.last
    # Desired (will FAIL initially): only the truly new line (Desc C) imported => 1
    expect(second_session.imported_transactions.count).to eq(1)
  end

  it 'deduplicates by normalized description + same date + same amount when external_id is absent (CSV)' do
    base_csv = [
      'data,valor,descricao',
      '2025-02-10,-123.45,Almoco Equipe'
    ]
    post import_sessions_path, params: { import_session: { source_type: 'csv', account_id: account.id, file: upload_csv(base_csv, filename: 'first2.csv') } }
    first = ImportSession.last
    expect(first.imported_transactions.count).to eq(1)

    dup_csv = [
      'data,valor,descricao',
      '2025-02-10,-123.45,ALMOÇO   equipe' # varying case + spaces + accent
    ]
    expect {
      post import_sessions_path, params: { import_session: { source_type: 'csv', account_id: account.id, file: upload_csv(dup_csv, filename: 'second2.csv') } }
    }.to change(ImportSession, :count).by(1)
    second = ImportSession.last
    # Desired: no new imported_transactions (duplicate skipped)
    expect(second.imported_transactions.count).to eq(0)
  end
end
