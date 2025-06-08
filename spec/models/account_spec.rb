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

  describe 'balance calculation' do
    let(:account) { create(:account, user: user, account_type: account_type) }
    let(:other_account) { create(:account, user: user, account_type: account_type) }
    let(:income_category) { create(:category, :income, user: user) }
    let(:expense_category) { create(:category, :expense, user: user) }

    before do
      # Clear any existing transactions to start fresh
      Transaction.delete_all
    end

    describe '#balance' do
      it 'calculates balance with no transactions' do
        expect(account.balance).to eq(0.0)
      end

      it 'calculates balance with income transactions (to account)' do
        create(:transaction, :income, :confirmed, to_account: account, 
               category: income_category, amount: 1000, user: user)
        
        expect(account.balance).to eq(1000.0)
      end

      it 'calculates balance with expense transactions (from account)' do
        create(:transaction, :expense, :confirmed, from_account: account, 
               to_account: other_account, category: expense_category, amount: 300, user: user)
        
        expect(account.balance).to eq(-300.0)
      end

      it 'calculates balance with transfer in (to account)' do
        create(:transaction, :transfer, :confirmed, from_account: other_account, 
               to_account: account, amount: 500, user: user)
        
        expect(account.balance).to eq(500.0)
      end

      it 'calculates balance with transfer out (from account)' do
        create(:transaction, :transfer, :confirmed, from_account: account, 
               to_account: other_account, amount: 200, user: user)
        
        expect(account.balance).to eq(-200.0)
      end

      it 'calculates balance with mixed transaction types' do
        # Income: +1000
        create(:transaction, :income, :confirmed, to_account: account, 
               category: income_category, amount: 1000, user: user)
        
        # Expense: -300
        create(:transaction, :expense, :confirmed, from_account: account, 
               to_account: other_account, category: expense_category, amount: 300, user: user)
        
        # Transfer in: +200
        create(:transaction, :transfer, :confirmed, from_account: other_account, 
               to_account: account, amount: 200, user: user)
        
        # Transfer out: -150
        create(:transaction, :transfer, :confirmed, from_account: account, 
               to_account: other_account, amount: 150, user: user)
        
        # Balance: 1000 - 300 + 200 - 150 = 750
        expect(account.balance).to eq(750.0)
      end

      it 'only includes confirmed transactions' do
        create(:transaction, :income, :confirmed, to_account: account, 
               category: income_category, amount: 1000, user: user)
        create(:transaction, :expense, :pending, from_account: account, 
               to_account: other_account, category: expense_category, amount: 300, user: user)
        
        # Only confirmed transaction should count
        expect(account.balance).to eq(1000.0)
      end
    end

    describe 'helper methods' do
      before do
        # Setup test transactions
        create(:transaction, :income, :confirmed, to_account: account, 
               category: income_category, amount: 1000, user: user)
        create(:transaction, :expense, :confirmed, from_account: account, 
               to_account: other_account, category: expense_category, amount: 300, user: user)
        create(:transaction, :transfer, :confirmed, from_account: other_account, 
               to_account: account, amount: 200, user: user)
        create(:transaction, :transfer, :confirmed, from_account: account, 
               to_account: other_account, amount: 150, user: user)
      end

      describe '#total_income' do
        it 'sums income transactions to this account' do
          expect(account.total_income).to eq(1000.0)
        end
      end

      describe '#total_expenses' do
        it 'sums expense transactions from this account' do
          expect(account.total_expenses).to eq(300.0)
        end
      end

      describe '#transfers_in' do
        it 'returns transfer transactions to this account' do
          transfers = account.transfers_in
          expect(transfers.count).to eq(1)
          expect(transfers.first.amount).to eq(200.0)
        end
      end

      describe '#transfers_out' do
        it 'returns transfer transactions from this account' do
          transfers = account.transfers_out
          expect(transfers.count).to eq(1)
          expect(transfers.first.amount).to eq(150.0)
        end
      end

      describe '#net_transfers' do
        it 'calculates net transfer amount (in - out)' do
          expect(account.net_transfers).to eq(50.0) # 200 - 150
        end
      end
    end
  end
end
