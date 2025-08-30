require 'rails_helper'

RSpec.describe 'ImportSessions possible duplicate highlighting', type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, :asset, user: user) }

  before { sign_in user }

  it 'displays badge and highlighting for transactions flagged as possible_duplicate' do
    session = create(:import_session, user: user, account: account, source_type: 'csv', raw_file: 'stub', file_digest: SecureRandom.hex)
    # One normal
    session.imported_transactions.create!(
      line_number: 1,
      raw_data: '{}',
      description: 'Compra Padaria',
      amount: 10.00,
      event_date: Date.new(2025,1,5),
      payment_date: Date.new(2025,1,5),
      status: 'pending'
    )
    # One flagged
    session.imported_transactions.create!(
      line_number: 2,
      raw_data: '{}',
      description: 'Compra Mercado',
      amount: 10.50,
      event_date: Date.new(2025,1,6),
      payment_date: Date.new(2025,1,6),
      status: 'pending',
      possible_duplicate: true
    )

    get import_session_path(session)
    expect(response).to have_http_status(:ok)
    # Badge label (will fail until implemented)
    expect(response.body).to include('Suspeita de duplicata')
    # Stats line
    expect(response.body).to include('Possíveis duplicadas')
  end
end
