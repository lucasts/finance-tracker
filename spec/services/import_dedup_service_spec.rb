require 'rails_helper'

RSpec.describe ImportDedupService, type: :service do
  let(:user)         { create(:user) }
  let(:account)      { create(:account, :asset, user: user) }
  let(:session1)     { create(:import_session, user: user, account: account, source_type: 'csv', raw_file: 'stub', file_digest: SecureRandom.hex) }

  # Helper to build parsed transaction hash similar to parsers output
  def tx(description:, amount:, date: Date.today)
    {
      line_number: 1,
      external_id: nil,
      raw_data: '{}',
      description: description,
      amount: amount,
      event_date: date,
      payment_date: date,
      transaction_type: 'expense',
      status: 'pending',
      parsed_data: {}
    }
  end

  context 'dedup heuristics' do
    it 'skips exact duplicate (same normalized description, date, amount)' do
      # existing
      session1.imported_transactions.create!(tx(description: 'Desc A', amount: 100.00, date: Date.new(2025, 1, 5)))
      session2 = create(:import_session, user: user, account: account, source_type: 'csv', raw_file: 'stub2', file_digest: SecureRandom.hex)

      created = described_class.call(import_session: session2, parsed_transactions: [
        tx(description: 'desc a', amount: 100.00, date: Date.new(2025, 1, 5))
      ])

      expect(created).to be_empty
      expect(session2.imported_transactions.count).to eq(0)
    end

    it 'skips tolerance duplicate (date +1 day, amount diff <= 0.01)' do
      session1.imported_transactions.create!(tx(description: 'Desc B', amount: 50.00, date: Date.new(2025, 1, 6)))
      session2 = create(:import_session, user: user, account: account, source_type: 'csv', raw_file: 'stub2', file_digest: SecureRandom.hex)

      created = described_class.call(import_session: session2, parsed_transactions: [
        tx(description: 'Desc B', amount: 50.01, date: Date.new(2025, 1, 7)) # within 1 day and 0.01 amount tolerance
      ])

      expect(created).to be_empty
    end

    it 'skips approximate description duplicate (one edit difference) same date & amount' do
      session1.imported_transactions.create!(tx(description: 'Almoco Equipe', amount: 123.45, date: Date.new(2025, 2, 10)))
      session2 = create(:import_session, user: user, account: account, source_type: 'csv', raw_file: 'stub2', file_digest: SecureRandom.hex)

      created = described_class.call(import_session: session2, parsed_transactions: [
        tx(description: 'Almoc Equipe', amount: 123.45, date: Date.new(2025, 2, 10)) # missing 'o'
      ])

      expect(created).to be_empty
    end

    it 'creates and flags similar (date diff 2 days, amount within 2) as possible_duplicate' do
      session1.imported_transactions.create!(tx(description: 'Desc C', amount: 80.00, date: Date.new(2025, 1, 5)))
      session2 = create(:import_session, user: user, account: account, source_type: 'csv', raw_file: 'stub2', file_digest: SecureRandom.hex)

      created = described_class.call(import_session: session2, parsed_transactions: [
        tx(description: 'Desc C', amount: 80.50, date: Date.new(2025, 1, 7)) # not duplicate (date diff >1) but similar (<=3 days & amount diff <=2)
      ])

      expect(created.size).to eq(1)
      rec = created.first
      expect(rec.possible_duplicate).to be true
      expect(rec.description).to eq('Desc C')
    end

    it 'creates when description differs beyond one edit and flags only if within similarity date/amount window (date diff >0)' do
      session1.imported_transactions.create!(tx(description: 'AAAAAA', amount: 10.00, date: Date.new(2025, 3, 1)))
      session2 = create(:import_session, user: user, account: account, source_type: 'csv', raw_file: 'stub2', file_digest: SecureRandom.hex)

      # Same date & amount would not mark similar (bucket empty prior). Use date +2 days within DATE_TOLERANCE_DAYS to trigger similarity flag.
      created = described_class.call(import_session: session2, parsed_transactions: [
        tx(description: 'AAABBB', amount: 10.00, date: Date.new(2025, 3, 3)) # >1 edits, date diff 2 days
      ])

      expect(created.size).to eq(1)
      expect(created.first.possible_duplicate).to be true
    end
  end
end
