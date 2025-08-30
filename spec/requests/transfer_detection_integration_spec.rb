require 'rails_helper'

RSpec.describe 'Transfer detection integration', type: :request do
  let(:user) { create(:user) }
  let(:checking_account) { create(:account, :asset, user: user, name: 'Conta Corrente') }
  let(:savings_account) { create(:account, :asset, user: user, name: 'Poupança') }

  before { sign_in user }

  it 'detects transfers during CSV import flow' do
    # Create CSV content with potential transfer
    csv_content = <<~CSV
      Data,Descrição,Valor
      2025-01-15,"Transferência para poupança",-500.00
    CSV

    # Import to checking account
    session1 = create(:import_session, 
      user: user, 
      account: checking_account,
      raw_file: csv_content,
      source_type: 'csv'
    )
    
    allow(CsvImportService).to receive(:call).and_return([
      {
        description: 'Transferência para poupança',
        amount: -500.00,
        event_date: Date.new(2025, 1, 15),
        raw_data: '{}'
      }
    ])

    # Second CSV with matching transfer
    csv_content2 = <<~CSV
      Data,Descrição,Valor
      2025-01-15,"Depósito recebido",500.00
    CSV

    session2 = create(:import_session,
      user: user,
      account: savings_account,
      raw_file: csv_content2,
      source_type: 'csv'
    )

    allow(CsvImportService).to receive(:call).and_return([
      {
        description: 'Depósito recebido',
        amount: 500.00,
        event_date: Date.new(2025, 1, 15),
        raw_data: '{}'
      }
    ])

    # Process first import
    ImportDedupService.call(import_session: session1, parsed_transactions: [
      {
        description: 'Transferência para poupança',
        amount: -500.00,
        event_date: Date.new(2025, 1, 15),
        raw_data: '{}'
      }
    ])

    # Process second import
    ImportDedupService.call(import_session: session2, parsed_transactions: [
      {
        description: 'Depósito recebido',
        amount: 500.00,
        event_date: Date.new(2025, 1, 15),
        raw_data: '{}'
      }
    ])

    # Run transfer detection
    TransferDetectionService.call(user: user)

    # Verify transfer detection worked
    tx1 = session1.imported_transactions.first
    tx2 = session2.imported_transactions.first

    expect(tx1.transfer_candidate).to be true
    expect(tx2.transfer_candidate).to be true
    expect(tx1.potential_transfer_with_id).to eq(tx2.id)
    expect(tx2.potential_transfer_with_id).to eq(tx1.id)

    # Test UI shows transfer info
    get import_session_path(session1)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Transferências candidatas')
    expect(response.body).to include('Transferência candidata')
  end
end
