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
    it { should have_many(:transactions) }
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
    let(:income_source_account) { create(:account, :income_source, user: user) }
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
        CreateTransactionService.call(
          amount: 1000,
          event_date: Date.current,
          payment_date: Date.current,
          user: user,
          description: 'Income transaction',
          transaction_type: 'income',
          category: income_category,
          entries_attributes: [
            { account_id: income_source_account.id, entry_type: 'credit', amount: 1000 },
            { account_id: account.id, entry_type: 'debit', amount: 1000 }
          ]
        )
        
        expect(account.balance).to eq(1000.0)
      end

      it 'calculates balance with expense transactions (from account)' do
        CreateTransactionService.call(
          amount: 300,
          event_date: Date.current,
          payment_date: Date.current,
          user: user,
          description: 'Expense transaction',
          transaction_type: 'expense',
          category: expense_category,
          entries_attributes: [
            { account_id: account.id, entry_type: 'credit', amount: 300 },
            { account_id: other_account.id, entry_type: 'debit', amount: 300 }
          ]
        )
        
        expect(account.balance).to eq(-300.0)
      end

      it 'calculates balance with transfer in (to account)' do
        CreateTransactionService.call(
          amount: 500,
          event_date: Date.current,
          payment_date: Date.current,
          user: user,
          description: 'Transfer in',
          transaction_type: 'transfer',
          entries_attributes: [
            { account_id: other_account.id, entry_type: 'credit', amount: 500 },
            { account_id: account.id, entry_type: 'debit', amount: 500 }
          ]
        )
        
        expect(account.balance).to eq(500.0)
      end

      it 'calculates balance with transfer out (from account)' do
        CreateTransactionService.call(
          amount: 200,
          event_date: Date.current,
          payment_date: Date.current,
          user: user,
          description: 'Transfer out',
          transaction_type: 'transfer',
          entries_attributes: [
            { account_id: account.id, entry_type: 'credit', amount: 200 },
            { account_id: other_account.id, entry_type: 'debit', amount: 200 }
          ]
        )
        
        expect(account.balance).to eq(-200.0)
      end

      it 'calculates balance with mixed transaction types' do
        # Income: +1000
        CreateTransactionService.call(
          amount: 1000,
          event_date: Date.current,
          payment_date: Date.current,
          user: user,
          description: 'Income',
          transaction_type: 'income',
          category: income_category,
          entries_attributes: [
            { account_id: income_source_account.id, entry_type: 'credit', amount: 1000 },
            { account_id: account.id, entry_type: 'debit', amount: 1000 }
          ]
        )
        
        # Expense: -300
        CreateTransactionService.call(
          amount: 300,
          event_date: Date.current,
          payment_date: Date.current,
          user: user,
          description: 'Expense',
          transaction_type: 'expense',
          category: expense_category,
          entries_attributes: [
            { account_id: account.id, entry_type: 'credit', amount: 300 },
            { account_id: other_account.id, entry_type: 'debit', amount: 300 }
          ]
        )
        
        # Transfer in: +200
        CreateTransactionService.call(
          amount: 200,
          event_date: Date.current,
          payment_date: Date.current,
          user: user,
          description: 'Transfer in',
          transaction_type: 'transfer',
          entries_attributes: [
            { account_id: other_account.id, entry_type: 'credit', amount: 200 },
            { account_id: account.id, entry_type: 'debit', amount: 200 }
          ]
        )
        
        # Transfer out: -150
        CreateTransactionService.call(
          amount: 150,
          event_date: Date.current,
          payment_date: Date.current,
          user: user,
          description: 'Transfer out',
          transaction_type: 'transfer',
          entries_attributes: [
            { account_id: account.id, entry_type: 'credit', amount: 150 },
            { account_id: other_account.id, entry_type: 'debit', amount: 150 }
          ]
        )
        
        # Balance: 1000 - 300 + 200 - 150 = 750
        expect(account.balance).to eq(750.0)
      end

      it 'only includes confirmed transactions' do
        # Create confirmed income transaction
        CreateTransactionService.call(
          amount: 1000,
          event_date: Date.current,
          payment_date: Date.current - 1.day, # Past date for confirmed status
          user: user,
          description: 'Confirmed income',
          transaction_type: 'income',
          category: income_category,
          entries_attributes: [
            { account_id: income_source_account.id, entry_type: 'credit', amount: 1000 },
            { account_id: account.id, entry_type: 'debit', amount: 1000 }
          ]
        )
        
        # Create pending expense transaction
        CreateTransactionService.call(
          amount: 300,
          event_date: Date.current,
          payment_date: Date.current + 1.day, # Future date for pending status
          user: user,
          description: 'Pending expense',
          transaction_type: 'expense',
          category: expense_category,
          entries_attributes: [
            { account_id: account.id, entry_type: 'credit', amount: 300 },
            { account_id: other_account.id, entry_type: 'debit', amount: 300 }
          ]
        )
        
        # Only confirmed transaction should count
        expect(account.balance).to eq(1000.0)
      end
    end

    describe 'helper methods' do
      before do
        # Setup test transactions
        CreateTransactionService.call(
          amount: 1000,
          event_date: Date.current,
          payment_date: Date.current,
          user: user,
          description: 'Income',
          transaction_type: 'income',
          category: income_category,
          entries_attributes: [
            { account_id: income_source_account.id, entry_type: 'credit', amount: 1000 },
            { account_id: account.id, entry_type: 'debit', amount: 1000 }
          ]
        )
        
        CreateTransactionService.call(
          amount: 300,
          event_date: Date.current,
          payment_date: Date.current,
          user: user,
          description: 'Expense',
          transaction_type: 'expense',
          category: expense_category,
          entries_attributes: [
            { account_id: account.id, entry_type: 'credit', amount: 300 },
            { account_id: other_account.id, entry_type: 'debit', amount: 300 }
          ]
        )
        
        CreateTransactionService.call(
          amount: 200,
          event_date: Date.current,
          payment_date: Date.current,
          user: user,
          description: 'Transfer in',
          transaction_type: 'transfer',
          entries_attributes: [
            { account_id: other_account.id, entry_type: 'credit', amount: 200 },
            { account_id: account.id, entry_type: 'debit', amount: 200 }
          ]
        )
        
        CreateTransactionService.call(
          amount: 150,
          event_date: Date.current,
          payment_date: Date.current,
          user: user,
          description: 'Transfer out',
          transaction_type: 'transfer',
          entries_attributes: [
            { account_id: account.id, entry_type: 'credit', amount: 150 },
            { account_id: other_account.id, entry_type: 'debit', amount: 150 }
          ]
        )
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
