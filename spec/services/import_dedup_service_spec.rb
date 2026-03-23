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

  context 'partial scenario (mixed batch)' do
    it 'creates one new and skips one exact duplicate in the same batch' do
      session1.imported_transactions.create!(tx(description: 'Mercado Extra', amount: 200.00, date: Date.new(2025, 5, 10)))
      session2 = create(:import_session, user: user, account: account, source_type: 'csv', raw_file: 'stub2', file_digest: SecureRandom.hex)

      parsed = [
        tx(description: 'Mercado Extra', amount: 200.00, date: Date.new(2025, 5, 10)), # exact dup — skip
        tx(description: 'Farmácia Popular', amount: 45.00, date: Date.new(2025, 5, 11)) # new — create
      ]

      created = described_class.call(import_session: session2, parsed_transactions: parsed)

      expect(created.size).to eq(1)
      expect(created.first.description).to eq('Farmácia Popular')
      expect(session2.imported_transactions.count).to eq(1)
    end

    it 'processes all new transactions when none are duplicates' do
      session2 = create(:import_session, user: user, account: account, source_type: 'csv', raw_file: 'stub2', file_digest: SecureRandom.hex)

      parsed = [
        tx(description: 'Conta Luz', amount: 180.00, date: Date.new(2025, 6, 1)),
        tx(description: 'Conta Agua', amount: 60.00, date: Date.new(2025, 6, 2))
      ]

      created = described_class.call(import_session: session2, parsed_transactions: parsed)

      expect(created.size).to eq(2)
    end
  end

  context 'missing external_id' do
    it 'creates transaction normally when external_id is nil (fingerprint does not depend on external_id)' do
      session2 = create(:import_session, user: user, account: account, source_type: 'csv', raw_file: 'stub2', file_digest: SecureRandom.hex)

      parsed = [ tx(description: 'Pagamento Cartao', amount: 750.00, date: Date.new(2025, 7, 15)).merge(external_id: nil) ]

      created = described_class.call(import_session: session2, parsed_transactions: parsed)

      expect(created.size).to eq(1)
      expect(created.first.description).to eq('Pagamento Cartao')
    end

    it 'deduplicates transactions with nil external_id using description+amount+date' do
      session1.imported_transactions.create!(tx(description: 'Pagamento Cartao', amount: 750.00, date: Date.new(2025, 7, 15)).merge(external_id: nil))
      session2 = create(:import_session, user: user, account: account, source_type: 'csv', raw_file: 'stub2', file_digest: SecureRandom.hex)

      created = described_class.call(import_session: session2, parsed_transactions: [
        tx(description: 'Pagamento Cartao', amount: 750.00, date: Date.new(2025, 7, 15)).merge(external_id: nil)
      ])

      expect(created).to be_empty
    end
  end

  context 'rounded amounts' do
    it 'skips a transaction with amount 50.004 when existing has 50.00 (within 0.01 absolute tolerance)' do
      session1.imported_transactions.create!(tx(description: 'Recarga Transporte', amount: 50.00, date: Date.new(2025, 8, 1)))
      session2 = create(:import_session, user: user, account: account, source_type: 'csv', raw_file: 'stub2', file_digest: SecureRandom.hex)

      created = described_class.call(import_session: session2, parsed_transactions: [
        tx(description: 'Recarga Transporte', amount: BigDecimal('50.004'), date: Date.new(2025, 8, 1))
      ])

      expect(created).to be_empty
    end

    it 'creates (not a dup) when amount differs by more than tolerance (0.02 above threshold)' do
      session1.imported_transactions.create!(tx(description: 'Recarga Transporte', amount: 50.00, date: Date.new(2025, 8, 1)))
      session2 = create(:import_session, user: user, account: account, source_type: 'csv', raw_file: 'stub2', file_digest: SecureRandom.hex)

      created = described_class.call(import_session: session2, parsed_transactions: [
        tx(description: 'Recarga Transporte', amount: BigDecimal('50.02'), date: Date.new(2025, 8, 1))
      ])

      # Amount diff = 0.02 > 0.01 tolerance, so it's not an exact/tolerance dup.
      # Same desc, same date, amount diff 0.02 <= 2.00 → similar flag
      expect(created.size).to eq(1)
      expect(created.first.possible_duplicate).to be true
    end
  end

  context 'cross-file dedup' do
    it 'detects duplicate against a transaction from a different import session (same account)' do
      session1.imported_transactions.create!(tx(description: 'Aluguel Apartamento', amount: 1500.00, date: Date.new(2025, 9, 5)))
      session2 = create(:import_session, user: user, account: account, source_type: 'ofx', raw_file: 'stub2', file_digest: SecureRandom.hex)

      created = described_class.call(import_session: session2, parsed_transactions: [
        tx(description: 'Aluguel Apartamento', amount: 1500.00, date: Date.new(2025, 9, 5))
      ])

      expect(created).to be_empty
    end

    it 'does NOT suppress a transaction that belongs to a different account (different user scope)' do
      other_account = create(:account, :asset, user: user)
      other_session = create(:import_session, user: user, account: other_account, source_type: 'csv', raw_file: 'stub_oa', file_digest: SecureRandom.hex)
      other_session.imported_transactions.create!(tx(description: 'Aluguel Apartamento', amount: 1500.00, date: Date.new(2025, 9, 5)))

      session2 = create(:import_session, user: user, account: account, source_type: 'csv', raw_file: 'stub2', file_digest: SecureRandom.hex)

      created = described_class.call(import_session: session2, parsed_transactions: [
        tx(description: 'Aluguel Apartamento', amount: 1500.00, date: Date.new(2025, 9, 5))
      ])

      # Different account → not a dedup; may be flagged as possible_duplicate via similar_by_amount_date?
      # but must be created
      expect(created.size).to eq(1)
    end
  end

  context 'boundary date window' do
    it 'flags as possible_duplicate when date difference is exactly DATE_TOLERANCE_DAYS (3 days)' do
      base_date = Date.new(2025, 10, 1)
      session1.imported_transactions.create!(tx(description: 'Supermercado BH', amount: 300.00, date: base_date))
      session2 = create(:import_session, user: user, account: account, source_type: 'csv', raw_file: 'stub2', file_digest: SecureRandom.hex)

      created = described_class.call(import_session: session2, parsed_transactions: [
        tx(description: 'Supermercado BH', amount: 300.50, date: base_date + 3) # 3 days = boundary, within similar window
      ])

      expect(created.size).to eq(1)
      expect(created.first.possible_duplicate).to be true
    end

    it 'does NOT flag as possible_duplicate when date difference exceeds DATE_TOLERANCE_DAYS (4 days)' do
      base_date = Date.new(2025, 10, 1)
      session1.imported_transactions.create!(tx(description: 'Supermercado BH', amount: 300.00, date: base_date))
      session2 = create(:import_session, user: user, account: account, source_type: 'csv', raw_file: 'stub2', file_digest: SecureRandom.hex)

      created = described_class.call(import_session: session2, parsed_transactions: [
        tx(description: 'Supermercado BH', amount: 300.50, date: base_date + 4) # 4 days > DATE_TOLERANCE_DAYS
      ])

      expect(created.size).to eq(1)
      expect(created.first.possible_duplicate).to be false
    end

    it 'does NOT flag as possible_duplicate when amount difference exceeds similar tolerance (> 2.00)' do
      base_date = Date.new(2025, 10, 1)
      session1.imported_transactions.create!(tx(description: 'Supermercado BH', amount: 300.00, date: base_date))
      session2 = create(:import_session, user: user, account: account, source_type: 'csv', raw_file: 'stub2', file_digest: SecureRandom.hex)

      created = described_class.call(import_session: session2, parsed_transactions: [
        tx(description: 'Supermercado BH', amount: 310.00, date: base_date + 1) # amount diff 10.00 > similar_amount_tolerance
      ])

      expect(created.size).to eq(1)
      expect(created.first.possible_duplicate).to be false
    end
  end
end
