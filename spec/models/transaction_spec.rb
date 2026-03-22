require 'rails_helper'

RSpec.describe Transaction, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }
  let(:category) { create(:category, user: user) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_presence_of(:amount) }
    it { is_expected.to validate_presence_of(:event_date) }
    it { is_expected.to validate_presence_of(:payment_date) }
    it { is_expected.to validate_presence_of(:transaction_type) }

    it 'validates transaction_type inclusion' do
      income_transaction = create(:transaction, :income, user: user)
      expect(income_transaction).to be_valid

      expense_transaction = create(:transaction, :expense, user: user)
      expect(expense_transaction).to be_valid

      transfer_transaction = create(:transaction, :transfer, user: user)
      expect(transfer_transaction).to be_valid

      # Test that invalid transaction_type raises an error
      transaction = build(:transaction, :expense, user: user,
                         from_account: create(:account, user: user),
                         category: create(:category, :expense, user: user))
      expect { transaction.transaction_type = 'invalid' }.to raise_error(ArgumentError)
    end

    describe 'category_type_compatibility' do
      let(:income_category) { create(:category, category_type: 'income', user: user) }
      let(:expense_category) { create(:category, category_type: 'expense', user: user) }

      it 'allows income transaction with income category' do
        transaction = create(:transaction, :income, category: income_category, user: user)
        expect(transaction).to be_valid
      end

      it 'allows expense transaction with expense category' do
        transaction = create(:transaction, :expense, category: expense_category, user: user)
        expect(transaction).to be_valid
      end

      it 'rejects income transaction with expense category' do
        transaction = build(:transaction, :income, category: expense_category, user: user)
        expect(transaction).not_to be_valid
        expect(transaction.errors[:category]).to include('é do tipo despesa, mas a transação é do tipo receita')
      end

      it 'rejects expense transaction with income category' do
        transaction = build(:transaction, :expense, category: income_category, user: user)
        expect(transaction).not_to be_valid
        expect(transaction.errors[:category]).to include('é do tipo receita, mas a transação é do tipo despesa')
      end
    end

    describe 'transfer validations' do
      it 'allows transfer without category' do
        transaction = create(:transaction, :transfer, user: user)
        expect(transaction).to be_valid
      end

      it 'rejects transfer with category' do
        transaction = build(:transaction, :transfer, category: create(:category, user: user), user: user)
        expect(transaction).not_to be_valid
        expect(transaction.errors[:category_id]).to include('Transferência não deve ter categoria')
      end

      it 'requires both from_account and to_account for transfers' do
        # Build a transfer with missing to_account via entries
        from_account = create(:account, user: user)
        transaction = build(:transaction, transaction_type: 'transfer', user: user, category: nil)
        transaction.entries.build([
          { account_id: from_account.id, entry_type: 'credit', amount: 100 }
          # Missing debit entry
        ])

        expect(transaction).not_to be_valid
        expect(transaction.errors[:base]).to include('É necessário informar conta de origem e destino para transferências')
      end

      it 'rejects transfer with same from_account and to_account' do
        account = create(:account, user: user)
        transaction = described_class.new(
          transaction_type: 'transfer',
          user: user,
          category: nil,
          amount: 100,
          description: 'Test transfer',
          event_date: Date.current,
          payment_date: Date.current
        )
        # Build two entries with the same account (which should be invalid)
        transaction.entries.build({ account_id: account.id, entry_type: 'debit', amount: 100 })
        transaction.entries.build({ account_id: account.id, entry_type: 'credit', amount: 100 })

        expect(transaction).not_to be_valid
        expect(transaction.errors[:base]).to include('Conta de origem e destino não podem ser iguais em uma transferência')
      end

      it 'allows transfer with different accounts' do
        from_acc = create(:account, user: user)
        to_acc = create(:account, user: user)
        transaction = create(:transaction, :transfer, user: user, from_account: from_acc, to_account: to_acc)
        expect(transaction).to be_valid
        expect(transaction.entries.map(&:account_id).uniq.count).to eq(2)
      end
    end

    describe 'category requirement for non-transfers' do
      it 'requires category for income transactions' do
        transaction = build(:transaction, :income, category: nil, user: user)
        expect(transaction).not_to be_valid
        expect(transaction.errors[:category_id]).to include('Categoria obrigatória')
      end

      it 'requires category for expense transactions' do
        transaction = build(:transaction, :expense, category: nil, user: user)
        expect(transaction).not_to be_valid
        expect(transaction.errors[:category_id]).to include('Categoria obrigatória')
      end
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:status).with_values(pending: 0, confirmed: 1, cancelled: 2) }
    it { is_expected.to define_enum_for(:recurrence_type).with_values(single: 0, recurring: 1, installment: 2) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:category).optional }
    it { is_expected.to belong_to(:credit_statement).optional }
    it { is_expected.to belong_to(:recurring_commitment).optional }
    it { is_expected.to belong_to(:installment_plan).optional }
    it { is_expected.to have_many(:entries) }
    it { is_expected.to have_many(:accounts).through(:entries) }

    # Additional association tests for comprehensive coverage
    it 'has many entries' do
      transaction = create(:transaction, user: user)
      expect(transaction.entries.count).to eq(2)
    end

    it 'has many accounts through entries' do
      transaction = create(:transaction, user: user)
      expect(transaction.accounts.count).to eq(2)
    end
  end

  describe 'scopes' do
    let!(:income_transaction) { create(:transaction, :income, user: user) }
    let!(:expense_transaction) { create(:transaction, :expense, user: user) }
    let!(:transfer_transaction) { create(:transaction, :transfer, user: user) }
    let!(:pending_transaction) { create(:transaction, :pending, user: user) }
    let!(:confirmed_transaction) { create(:transaction, :confirmed, user: user) }

    it 'filters income transactions' do
      expect(described_class.income).to include(income_transaction)
      expect(described_class.income).not_to include(expense_transaction)
      expect(described_class.income).not_to include(transfer_transaction)
    end

    it 'filters expense transactions' do
      expect(described_class.expense).to include(expense_transaction)
      expect(described_class.expense).not_to include(income_transaction)
      expect(described_class.expense).not_to include(transfer_transaction)
    end

    it 'filters transfer transactions' do
      expect(described_class.transfer).to include(transfer_transaction)
      expect(described_class.transfer).not_to include(income_transaction)
      expect(described_class.transfer).not_to include(expense_transaction)
    end

    it 'filters pending transactions' do
      expect(described_class.pending).to include(pending_transaction)
      expect(described_class.pending).not_to include(confirmed_transaction)
    end

    describe '.upcoming_payments' do
      it 'returns pending or confirmed transactions within the next month ordered by event_date' do
        travel_to(Time.zone.local(2025, 1, 1)) do
          in_range_pending = create(:transaction, :expense, status: :pending, event_date: 1.week.from_now, payment_date: 1.week.from_now, user: user)
          in_range_confirmed = create(:transaction, :expense, status: :confirmed, event_date: 2.weeks.from_now, payment_date: 2.weeks.from_now, user: user)
          cancelled_in_range = create(:transaction, :expense, status: :cancelled, event_date: 3.weeks.from_now, payment_date: 3.weeks.from_now, user: user)
          past_transaction = create(:transaction, :expense, status: :confirmed, event_date: 1.week.ago, payment_date: 1.week.ago, user: user)
          distant_future = create(:transaction, :expense, status: :pending, event_date: 2.months.from_now, payment_date: 2.months.from_now, user: user)

          result = described_class.where(user: user).upcoming_payments

          expect(result).to eq([ in_range_pending, in_range_confirmed ])
          expect(result).not_to include(cancelled_in_range, past_transaction, distant_future)
        end
      end
    end
  end

  describe 'business methods' do
    describe '#competence_month' do
      it 'returns competence month based on event_date' do
        transaction = build(:transaction, event_date: Date.new(2025, 3, 15))
        expect(transaction.competence_month).to eq('2025-03')
      end
    end

    describe '#payment_month' do
      it 'returns payment month based on payment_date' do
        transaction = build(:transaction, payment_date: Date.new(2025, 4, 20))
        expect(transaction.payment_month).to eq('2025-04')
      end

      it 'uses event_date as fallback if payment_date is nil' do
        transaction = build(:transaction, event_date: Date.new(2025, 3, 15), payment_date: nil)
        expect(transaction.payment_month).to eq('2025-03')
      end
    end

    describe '#future_transaction?' do
      it 'returns true if payment_date is in the future' do
        transaction = build(:transaction, payment_date: 1.week.from_now)
        expect(transaction.future_transaction?).to be true
      end

      it 'returns false if payment_date is in the past' do
        transaction = build(:transaction, payment_date: 1.week.ago)
        expect(transaction.future_transaction?).to be false
      end
    end

    describe 'classification methods' do
      it 'identifies single transaction' do
        transaction = build(:transaction, recurrence_type: 'single')
        expect(transaction.single_transaction?).to be true
      end

      it 'identifies recurring transaction' do
        commitment = create(:recurring_commitment, user: user)
        transaction = build(:transaction, recurrence_type: 'recurring', recurring_commitment: commitment)
        expect(transaction.recurring_transaction?).to be true
      end

      it 'identifies installment transaction' do
        plan = create(:installment_plan, user: user)
        transaction = build(:transaction, recurrence_type: 'installment', installment_plan: plan)
        expect(transaction.installment_transaction?).to be true
      end
    end

    describe '#installment_status' do
      it 'returns installment status for installment transactions' do
        plan = create(:installment_plan, installment_count: 12, user: user)
        transaction = build(:transaction, recurrence_type: 'installment', installment_plan: plan, installment_number: 3)
        expect(transaction.installment_status).to eq('3/12')
      end

      it 'returns nil for non-installment transactions' do
        transaction = build(:transaction, recurrence_type: 'single')
        expect(transaction.installment_status).to be_nil
      end
    end
  end

  describe 'mutual exclusivity validations' do
    it 'allows single transaction without associations' do
      transaction = create(:transaction,
        :expense,  # This will include a proper expense category
        recurrence_type: 'single',
        recurring_commitment: nil,
        installment_plan: nil,
        user: user
      )
      expect(transaction).to be_valid
    end

    it 'validates that recurring transaction must have recurring_commitment' do
      transaction = build(:transaction,
        recurrence_type: 'recurring',
        recurring_commitment: nil,
        user: user
      )
      expect(transaction).not_to be_valid
      expect(transaction.errors[:recurring_commitment]).to include('must be present for recurring transactions')
    end

    it 'validates that installment transaction must have installment_plan' do
      transaction = build(:transaction,
        recurrence_type: 'installment',
        installment_plan: nil,
        user: user
      )
      expect(transaction).not_to be_valid
      expect(transaction.errors[:installment_plan]).to include('must be present for installment transactions')
    end

    it 'prevents single transaction with associations' do
      plan = create(:installment_plan, user: user)
      transaction = build(:transaction,
        recurrence_type: 'single',
        installment_plan: plan,
        user: user
      )
      expect(transaction).not_to be_valid
      expect(transaction.errors[:base]).to include('Single transactions cannot have recurring commitment or installment plan')
    end
  end

  describe 'automatic status callbacks' do
    it 'sets status automatically for future transactions' do
      transaction = CreateTransactionService.call(
        amount: 100,
        event_date: Date.current,
        payment_date: 1.week.from_now,
        user: user,
        description: 'Future transaction',
        transaction_type: 'expense',
        category: create(:category, :expense, user: user),
        entries_attributes: [
          { account_id: create(:account, user: user).id, entry_type: 'debit', amount: 100 },
          { account_id: create(:account, :expense_destination, user: user).id, entry_type: 'credit', amount: 100 }
        ]
      )
      expect(transaction.status).to eq('pending')
    end

    it 'sets status automatically for past transactions' do
      transaction = CreateTransactionService.call(
        amount: 100,
        event_date: Date.current,
        payment_date: 1.week.ago,
        user: user,
        description: 'Past transaction',
        transaction_type: 'expense',
        category: create(:category, :expense, user: user),
        entries_attributes: [
          { account_id: create(:account, user: user).id, entry_type: 'debit', amount: 100 },
          { account_id: create(:account, :expense_destination, user: user).id, entry_type: 'credit', amount: 100 }
        ]
      )
      expect(transaction.status).to eq('confirmed')
    end

    it 'atualiza status quando payment_date muda' do
      transaction = create(:transaction,
        payment_date: 1.week.ago,
        status: 'confirmed',
        user: user
      )
      transaction.update!(payment_date: 1.week.from_now)
      expect(transaction.status).to eq('pending')
    end

    it 'does not update status of cancelled transactions' do
      transaction = create(:transaction,
        payment_date: 1.week.ago,
        status: 'cancelled',
        user: user
      )
      transaction.update!(payment_date: 1.week.from_now)
      expect(transaction.status).to eq('cancelled')
    end
  end

  describe 'edge cases' do
    it 'aceita valores extremos' do
      transaction = create(:transaction,
        :expense,
        amount: 99_999_999.99,
        user: user
      )
      expect(transaction).to be_valid
    end

    it 'aceita datas distantes no passado' do
      transaction = create(:transaction,
        :expense,
        event_date: Date.new(1900, 1, 1),
        payment_date: Date.new(1900, 1, 1),
        user: user
      )
      expect(transaction).to be_valid
    end

    it 'aceita datas distantes no futuro' do
      transaction = create(:transaction,
        :expense,
        event_date: Date.new(2099, 12, 31),
        payment_date: Date.new(2099, 12, 31),
        user: user
      )
      expect(transaction).to be_valid
    end

    it 'accepts very long descriptions' do
      long_description = 'A' * 1000
      transaction = create(:transaction,
        :expense,
        description: long_description,
        user: user
      )
      expect(transaction).to be_valid
    end

    it 'accepts decimal values with precision' do
      transaction = create(:transaction,
        :expense,
        amount: 123.456789,
        user: user
      )
      expect(transaction).to be_valid
    end
  end
end
