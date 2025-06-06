require 'rails_helper'

RSpec.describe Transaction, type: :model do
  let(:user) { create(:user) }
  let(:account) { create(:account, user: user) }
  let(:category) { create(:category, user: user) }

  describe 'validations' do
    it { should validate_presence_of(:description) }
    it { should validate_presence_of(:amount) }
    it { should validate_presence_of(:event_date) }
    it { should validate_presence_of(:payment_date) }
    it { should validate_presence_of(:transaction_type) }
    it { should validate_inclusion_of(:transaction_type).in_array(%w[income expense]) }
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(pending: 0, confirmed: 1, cancelled: 2) }
    it { should define_enum_for(:recurrence_type).with_values(single: 0, recurring: 1, installment: 2) }
  end

  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:from_account).class_name('Account') }
    it { should belong_to(:to_account).class_name('Account').optional }
    it { should belong_to(:category) }
    it { should belong_to(:credit_statement).optional }
    it { should belong_to(:recurring_commitment).optional }
    it { should belong_to(:installment_plan).optional }
  end

  describe 'scopes' do
    let!(:income_transaction) { create(:transaction, :income, user: user) }
    let!(:expense_transaction) { create(:transaction, :expense, user: user) }
    let!(:pending_transaction) { create(:transaction, :pending, user: user) }
    let!(:confirmed_transaction) { create(:transaction, :confirmed, user: user) }

    it 'filters income transactions' do
      expect(Transaction.income).to include(income_transaction)
      expect(Transaction.income).not_to include(expense_transaction)
    end

    it 'filters expense transactions' do
      expect(Transaction.expense).to include(expense_transaction)
      expect(Transaction.expense).not_to include(income_transaction)
    end

    it 'filters pending transactions' do
      expect(Transaction.pending).to include(pending_transaction)
      expect(Transaction.pending).not_to include(confirmed_transaction)
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
      transaction = build(:transaction, 
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
      transaction = build(:transaction, 
        payment_date: 1.week.from_now,
        status: nil,
        user: user
      )
      transaction.save!
      expect(transaction.status).to eq('pending')
    end

    it 'sets status automatically for past transactions' do
      transaction = build(:transaction, 
        payment_date: 1.week.ago,
        status: nil,
        user: user
      )
      transaction.save!
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
      transaction = build(:transaction, 
        amount: 999999999.99,
        user: user
      )
      expect(transaction).to be_valid
    end

    it 'aceita datas distantes no passado' do
      transaction = build(:transaction, 
        event_date: Date.new(1900, 1, 1),
        payment_date: Date.new(1900, 1, 1),
        user: user
      )
      expect(transaction).to be_valid
    end

    it 'aceita datas distantes no futuro' do
      transaction = build(:transaction, 
        event_date: Date.new(2099, 12, 31),
        payment_date: Date.new(2099, 12, 31),
        user: user
      )
      expect(transaction).to be_valid
    end

    it 'accepts very long descriptions' do
      long_description = 'A' * 1000
      transaction = build(:transaction, 
        description: long_description,
        user: user
      )
      expect(transaction).to be_valid
    end

    it 'accepts decimal values with precision' do
      transaction = build(:transaction, 
        amount: 123.456789,
        user: user
      )
      expect(transaction).to be_valid
    end
  end
end
