require 'rails_helper'

RSpec.describe Account, type: :model do
  let(:user) { create(:user) }
  let(:account_type) { create(:account_type) }

  describe 'validations' do
    it { should validate_presence_of(:name) }
  end

  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:account_type) }
    it { should have_many(:transactions_from).class_name('Transaction').with_foreign_key('from_account_id') }
    it { should have_many(:transactions_to).class_name('Transaction').with_foreign_key('to_account_id') }
    it { should have_many(:import_sessions) }
  end

  describe 'edge cases' do
    it 'accepts very long names' do
      long_name = 'A' * 255
      account = build(:account, name: long_name, user: user, account_type: account_type)
      expect(account).to be_valid
    end

    it 'accepts special characters in name' do
      special_name = "Conta C&A - João's Account 123!@#$%"
      account = build(:account, name: special_name, user: user, account_type: account_type)
      expect(account).to be_valid
    end
  end
end
