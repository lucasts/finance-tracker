require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
  end

  describe 'associations' do
    it { is_expected.to have_many(:accounts).dependent(:destroy) }
    it { is_expected.to have_many(:categories).dependent(:destroy) }
    it { is_expected.to have_many(:transactions).dependent(:destroy) }
    it { is_expected.to have_many(:installment_plans).dependent(:destroy) }
    it { is_expected.to have_many(:recurring_commitments).dependent(:destroy) }
  end

  describe 'business methods' do
    let(:user) { create(:user) }
    let(:checking_account) { create(:account, :asset, user: user) }
    let(:credit_account) { create(:account, :asset, user: user) }
    let(:income_category) { create(:category, :income, user: user) }
    let(:expense_category) { create(:category, :expense, user: user) }

    before do
      # Creates some transactions for testing using CreateTransactionService
      CreateTransactionService.call(
        user: user,
        description: "Income transaction",
        amount: 1000,
        event_date: Date.current,
        payment_date: Date.current,
        transaction_type: 'income',
        category: income_category,
        status: 'confirmed',
        entries_attributes: [
          { account_id: checking_account.id, entry_type: 'debit', amount: 1000 },
          { account_id: create(:account, :income_source, user: user).id, entry_type: 'credit', amount: 1000 }
        ]
      )

      CreateTransactionService.call(
        user: user,
        description: "Expense from checking",
        amount: 300,
        event_date: Date.current,
        payment_date: Date.current,
        transaction_type: 'expense',
        category: expense_category,
        status: 'confirmed',
        entries_attributes: [
          { account_id: create(:account, :expense_destination, user: user).id, entry_type: 'debit', amount: 300 },
          { account_id: checking_account.id, entry_type: 'credit', amount: 300 }
        ]
      )

      CreateTransactionService.call(
        user: user,
        description: "Expense from credit",
        amount: 200,
        event_date: Date.current,
        payment_date: Date.current,
        transaction_type: 'expense',
        category: expense_category,
        status: 'confirmed',
        entries_attributes: [
          { account_id: create(:account, :expense_destination, user: user).id, entry_type: 'debit', amount: 200 },
          { account_id: credit_account.id, entry_type: 'credit', amount: 200 }
        ]
      )
    end

    describe '#total_balance' do
      it 'calculates total balance from all accounts' do
        expect(user.total_balance).to be_within(0.01).of(500.0) # 1000 - 300 - 200
      end
    end

    describe '#monthly_income' do
      it 'calculates current month income' do
        expect(user.monthly_income).to be_within(0.01).of(1000.0)
      end

      it 'calculates income for a specific month' do
        expect(user.monthly_income(Date.current)).to be_within(0.01).of(1000.0)
      end
    end

    describe '#monthly_expenses' do
      it 'calculates current month expenses' do
        expect(user.monthly_expenses).to be_within(0.01).of(500.0) # 300 + 200
      end

      it 'calculates expenses for a specific month' do
        expect(user.monthly_expenses(Date.current)).to be_within(0.01).of(500.0)
      end
    end

    describe '#monthly_balance' do
      it 'calculates current month balance' do
        expect(user.monthly_balance).to be_within(0.01).of(500.0) # 1000 - 500
      end

      it 'calculates balance for a specific month' do
        expect(user.monthly_balance(Date.current)).to be_within(0.01).of(500.0)
      end
    end

    describe '#pending_transactions_count' do
      it 'counts pending transactions' do
        create(:transaction, :pending, user: user, from_account: checking_account,
               category: expense_category, amount: 100, event_date: Date.tomorrow)

        expect(user.pending_transactions_count).to eq(1)
      end
    end

    describe '#upcoming_payments' do
      it 'returns future payments' do
        future_transaction = create(:transaction, :pending, user: user,
                                   from_account: checking_account, category: expense_category,
                                   amount: 150, event_date: 1.week.from_now)

        expect(user.upcoming_payments).to include(future_transaction)
      end

      it 'limits the number of results' do
        12.times do |i|
          create(:transaction, :pending, user: user, from_account: checking_account,
                 category: expense_category, amount: 50, event_date: (i + 1).days.from_now)
        end

        expect(user.upcoming_payments.count).to eq(10) # Default limit
        expect(user.upcoming_payments(5).count).to eq(5) # Custom limit
      end
    end
  end

  describe 'edge cases' do
    let(:user) { create(:user) }

    it 'handles user without transactions' do
      expect(user.total_balance).to eq(0.0)
      expect(user.monthly_income).to eq(0.0)
      expect(user.monthly_expenses).to eq(0.0)
      expect(user.monthly_balance).to eq(0.0)
      expect(user.pending_transactions_count).to eq(0)
      expect(user.upcoming_payments).to be_empty
    end

    it 'handles extreme decimal values' do
      account = create(:account, user: user)
      income_category = create(:category, :income, user: user)
      expense_category = create(:category, :expense, user: user)

      create(:transaction, :income, :confirmed, user: user, to_account: account,
             category: income_category, amount: 999999.99, event_date: Date.current)
      create(:transaction, :expense, :confirmed, user: user, from_account: account,
             category: expense_category, amount: 0.01, event_date: Date.current)

      expect(user.monthly_balance).to be_within(0.01).of(999999.98)
    end

    it 'handles extreme dates' do
      account = create(:account, user: user)
      income_category = create(:category, :income, user: user)

      # Very old transaction - should not affect current month
      create(:transaction, :income, user: user, to_account: account,
             category: income_category, amount: 1000, event_date: Date.new(1900, 1, 1))

      expect(user.monthly_income).to eq(0.0)
    end
  end

  describe 'scopes and filters' do
    let(:first_user) { create(:user, email: 'user1@test.com') }
    let(:second_user) { create(:user, email: 'user2@test.com') }

    it 'isolates data between users' do
      account1 = create(:account, user: first_user)
      account2 = create(:account, user: second_user)
      category1 = create(:category, user: first_user)
      category2 = create(:category, user: second_user)

      transaction1 = create(:transaction, user: first_user, from_account: account1, category: category1)
      transaction2 = create(:transaction, user: second_user, from_account: account2, category: category2)

      expect(first_user.transactions).to include(transaction1)
      expect(first_user.transactions).not_to include(transaction2)
      expect(second_user.transactions).to include(transaction2)
      expect(second_user.transactions).not_to include(transaction1)
    end
  end
end
