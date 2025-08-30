require 'rails_helper'

RSpec.describe ImportedTransaction, '#fingerprint' do
  let(:user) { create(:user) }
  let(:account) { create(:account, :asset, user: user) }
  let(:session) { create(:import_session, user: user, account: account) }

  describe 'fingerprint generation' do
    let(:base_attrs) do
      {
        import_session: session,
        line_number: 1,
        raw_data: '{}',
        description: 'Compra Mercado São Paulo',
        amount: 123.45,
        event_date: Date.new(2025, 1, 15),
        payment_date: Date.new(2025, 1, 16)
      }
    end

    it 'populates fingerprint on create' do
      tx = build(:imported_transaction, base_attrs)
      expect(tx.fingerprint).to be_nil
      tx.save!
      expect(tx.fingerprint).to be_present
      expect(tx.fingerprint_version).to eq(1)
      expect(tx.fingerprint.length).to eq(48)
    end

    it 'generates stable fingerprint for equivalent semantic descriptions' do
      tx1 = create(:imported_transaction, base_attrs.merge(
        description: 'Compra  Mercado   São Paulo!!'
      ))
      tx2 = create(:imported_transaction, base_attrs.merge(
        description: 'compra mercado sao paulo'
      ))
      
      expect(tx1.fingerprint).to eq(tx2.fingerprint)
    end
  end
end
