require 'rails_helper'

RSpec.describe 'Security', type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }
  let(:category) { create(:category, user: user) }

  it 'protects against SQL injection in transaction creation' do
    sign_in user
    post transactions_path, params: { 
      transaction: { 
        amount: 100, 
        event_date: Date.today,
        payment_date: Date.today,
        from_account_id: account.id, 
        category_id: category.id, 
        description: "; DROP TABLE users; --",
        transaction_type: 'expense'
      } 
    }
    # Pode ser redirect (sucesso) ou unprocessable_entity (validação falhou)
    expect(response).to have_http_status(:redirect).or have_http_status(:unprocessable_entity)
    
    # Se foi criado, verificar que não há código malicioso
    if response.status == 302
      expect(Transaction.last.description).to eq("; DROP TABLE users; --")
      expect(Transaction.count).to be > 0 # A tabela ainda existe
    end
  end

  it 'blocks invalid/malicious file uploads' do
    sign_in user
    file = fixture_file_upload(Rails.root.join('spec/fixtures/files/malicious.exe'), 'application/octet-stream')
    post import_sessions_path, params: { import_session: { file: file } }
    expect(response).to have_http_status(:unprocessable_entity).or have_http_status(:bad_request)
  end
end
