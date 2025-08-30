require 'rails_helper'

RSpec.describe 'Transfer detection', type: :service do
  let(:user) { create(:user) }
  let(:checking_account) { create(:account, :asset, user: user, name: 'Conta Corrente') }
  let(:savings_account) { create(:account, :asset, user: user, name: 'Poupança') }
  let(:other_user) { create(:user) }
  let(:other_account) { create(:account, :asset, user: other_user, name: 'Outra Conta') }

  describe 'TransferDetectionService' do
    let(:service) { TransferDetectionService }

    it 'detects transfer candidates with same amount and close dates' do
      session1 = create(:import_session, user: user, account: checking_account)
      session2 = create(:import_session, user: user, account: savings_account)
      
      # Outgoing transfer from checking
      tx1 = create(:imported_transaction,
        import_session: session1,
        description: 'Transferência para poupança',
        amount: -500.00,
        event_date: Date.new(2025, 1, 15)
      )
      
      # Incoming transfer to savings
      tx2 = create(:imported_transaction,
        import_session: session2,
        description: 'Depósito recebido',
        amount: 500.00,
        event_date: Date.new(2025, 1, 15)
      )

      service.call(user: user)

      tx1.reload
      tx2.reload

      expect(tx1.transfer_candidate).to be true
      expect(tx2.transfer_candidate).to be true
      expect(tx1.potential_transfer_with_id).to eq(tx2.id)
      expect(tx2.potential_transfer_with_id).to eq(tx1.id)
    end

    it 'tolerates small amount differences (within 0.01)' do
      session1 = create(:import_session, user: user, account: checking_account)
      session2 = create(:import_session, user: user, account: savings_account)
      
      tx1 = create(:imported_transaction,
        import_session: session1,
        amount: -100.00,
        event_date: Date.new(2025, 1, 15)
      )
      
      tx2 = create(:imported_transaction,
        import_session: session2,
        amount: 99.99,  # 0.01 difference
        event_date: Date.new(2025, 1, 15)
      )

      service.call(user: user)

      expect(tx1.reload.transfer_candidate).to be true
      expect(tx2.reload.transfer_candidate).to be true
    end

    it 'tolerates date differences within 2 days' do
      session1 = create(:import_session, user: user, account: checking_account)
      session2 = create(:import_session, user: user, account: savings_account)
      
      tx1 = create(:imported_transaction,
        import_session: session1,
        amount: -200.00,
        event_date: Date.new(2025, 1, 15)
      )
      
      tx2 = create(:imported_transaction,
        import_session: session2,
        amount: 200.00,
        event_date: Date.new(2025, 1, 17)  # 2 days later
      )

      service.call(user: user)

      expect(tx1.reload.transfer_candidate).to be true
      expect(tx2.reload.transfer_candidate).to be true
    end

    it 'does not detect transfers between different users' do
      session1 = create(:import_session, user: user, account: checking_account)
      session2 = create(:import_session, user: other_user, account: other_account)
      
      tx1 = create(:imported_transaction,
        import_session: session1,
        amount: -300.00,
        event_date: Date.new(2025, 1, 15)
      )
      
      tx2 = create(:imported_transaction,
        import_session: session2,
        amount: 300.00,
        event_date: Date.new(2025, 1, 15)
      )

      service.call(user: user)
      service.call(user: other_user)

      expect(tx1.reload.transfer_candidate).to be false
      expect(tx2.reload.transfer_candidate).to be false
    end

    it 'does not detect transfers in same account' do
      session = create(:import_session, user: user, account: checking_account)
      
      tx1 = create(:imported_transaction,
        import_session: session,
        amount: -100.00,
        event_date: Date.new(2025, 1, 15)
      )
      
      tx2 = create(:imported_transaction,
        import_session: session,
        amount: 100.00,
        event_date: Date.new(2025, 1, 15)
      )

      service.call(user: user)

      expect(tx1.reload.transfer_candidate).to be false
      expect(tx2.reload.transfer_candidate).to be false
    end

    it 'does not detect when amounts are too different' do
      session1 = create(:import_session, user: user, account: checking_account)
      session2 = create(:import_session, user: user, account: savings_account)
      
      tx1 = create(:imported_transaction,
        import_session: session1,
        amount: -100.00,
        event_date: Date.new(2025, 1, 15)
      )
      
      tx2 = create(:imported_transaction,
        import_session: session2,
        amount: 100.50,  # 0.50 difference (> 0.01)
        event_date: Date.new(2025, 1, 15)
      )

      service.call(user: user)

      expect(tx1.reload.transfer_candidate).to be false
      expect(tx2.reload.transfer_candidate).to be false
    end

    it 'does not detect when dates are too far apart' do
      session1 = create(:import_session, user: user, account: checking_account)
      session2 = create(:import_session, user: user, account: savings_account)
      
      tx1 = create(:imported_transaction,
        import_session: session1,
        amount: -150.00,
        event_date: Date.new(2025, 1, 15)
      )
      
      tx2 = create(:imported_transaction,
        import_session: session2,
        amount: 150.00,
        event_date: Date.new(2025, 1, 20)  # 5 days later (> 2 days)
      )

      service.call(user: user)

      expect(tx1.reload.transfer_candidate).to be false
      expect(tx2.reload.transfer_candidate).to be false
    end
  end
end
