require 'rails_helper'

RSpec.describe RecurringCommitment, type: :model do
  let(:user) { create(:user) }
  let(:category) { create(:category, user: user) }
  let(:from_account) { create(:account, user: user) }
  let(:to_account) { create(:account, user: user) }
  let(:commitment) { create(:recurring_commitment, user: user, category: category, from_account: from_account, to_account: to_account) }

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:category_id) }
    it { should validate_presence_of(:recurrence_frequency) }
    it { should validate_presence_of(:start_date) }
    it { should validate_presence_of(:status) }
    it { should validate_presence_of(:from_account) }
    
    it { should validate_inclusion_of(:recurrence_frequency)
           .in_array(%w[monthly weekly annual]) }
    
    it { should validate_numericality_of(:default_amount)
           .is_greater_than(0)
           .allow_nil }
    
    it 'accepts valid commitments' do
      commitment = build(:recurring_commitment,
                        name: 'Aluguel',
                        default_amount: 1500,
                        recurrence_frequency: 'monthly',
                        start_date: Date.current,
                        user: user,
                        category: category,
                        from_account: from_account,
                        to_account: to_account)
      expect(commitment).to be_valid
    end
    
    it 'rejects invalid frequencies' do
      expect(build(:recurring_commitment, recurrence_frequency: 'daily', user: user, category: category)).not_to be_valid
      expect(build(:recurring_commitment, recurrence_frequency: 'invalid', user: user, category: category)).not_to be_valid
    end
    
    it 'accepts null default_amount' do
      commitment = build(:recurring_commitment, default_amount: nil, user: user, category: category, from_account: from_account, to_account: to_account)
      expect(commitment).to be_valid
    end
    
    it 'rejects negative default_amount' do
      commitment = build(:recurring_commitment, default_amount: -100, user: user, category: category)
      expect(commitment).not_to be_valid
    end
  end

  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:category) }
    it { should belong_to(:from_account).class_name('Account') }
    it { should have_many(:transactions).dependent(:restrict_with_error) }
    
    it 'belongs to a user and category' do
      expect(commitment.user).to be_present
      expect(commitment.category).to be_present
      expect(commitment.user).to be_a(User)
      expect(commitment.category).to be_a(Category)
    end
    
    it 'can have many transactions' do
      transaction1 = create(:transaction, :recurring, recurring_commitment: commitment, user: user)
      transaction2 = create(:transaction, :recurring, recurring_commitment: commitment, user: user)
      
      expect(commitment.transactions).to include(transaction1, transaction2)
      expect(commitment.transactions.count).to eq(2)
    end
    
    it 'does not allow deletion if there are transactions' do
      create(:transaction, :recurring, recurring_commitment: commitment, user: user)
      
      expect { commitment.destroy }.not_to change(RecurringCommitment, :count)
      expect(commitment.errors[:base]).to be_present
    end
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(active: 0, paused: 1, closed: 2) }
    
    it 'has default status as active' do
      commitment = create(:recurring_commitment, user: user, category: category)
      expect(commitment.status).to eq('active')
    end
  end

  describe 'scopes' do
    let!(:active_commitment) { create(:recurring_commitment, status: :active, user: user, category: category) }
    let!(:paused_commitment) { create(:recurring_commitment, status: :paused, user: user, category: category) }
    let!(:closed_commitment) { create(:recurring_commitment, status: :closed, user: user, category: category) }
    let!(:weekly_commitment) { create(:recurring_commitment, recurrence_frequency: 'weekly', user: user, category: category) }
    let!(:monthly_commitment) { create(:recurring_commitment, recurrence_frequency: 'monthly', user: user, category: category) }
    let!(:commitment_with_amount) { create(:recurring_commitment, default_amount: 100, user: user, category: category) }
    let!(:commitment_without_amount) { create(:recurring_commitment, default_amount: nil, user: user, category: category) }

    describe '.active_commitments' do
      it 'returns only active commitments' do
        expect(RecurringCommitment.active_commitments).to include(active_commitment)
        expect(RecurringCommitment.active_commitments).not_to include(paused_commitment, closed_commitment)
      end
    end

    describe '.by_frequency' do
      it 'filters by frequency' do
        expect(RecurringCommitment.by_frequency('weekly')).to include(weekly_commitment)
        expect(RecurringCommitment.by_frequency('monthly')).to include(monthly_commitment)
        expect(RecurringCommitment.by_frequency('monthly')).not_to include(weekly_commitment)
      end
    end

    describe '.monthly_commitments' do
      it 'returns only monthly commitments' do
        monthly_commitments = RecurringCommitment.monthly_commitments
        expect(monthly_commitments.map(&:recurrence_frequency).uniq).to eq(['monthly'])
      end
    end

    describe '.with_default_amount' do
      it 'returns only commitments with default amount' do
        expect(RecurringCommitment.with_default_amount).to include(commitment_with_amount)
        expect(RecurringCommitment.with_default_amount).not_to include(commitment_without_amount)
      end
    end

    describe '.current_active' do
      it 'returns active commitments in the period' do
        current_commitment = create(:recurring_commitment, 
                                   status: :active,
                                   start_date: 1.month.ago,
                                   end_date: 1.month.from_now,
                                   user: user, 
                                   category: category)
        
        future_commitment = create(:recurring_commitment,
                                  status: :active,
                                  start_date: 1.month.from_now,
                                  user: user,
                                  category: category)
        
        expired_commitment = create(:recurring_commitment,
                                   status: :active,
                                   start_date: 2.months.ago,
                                   end_date: 1.day.ago,
                                   user: user,
                                   category: category)
        
        result = RecurringCommitment.current_active
        expect(result).to include(current_commitment)
        expect(result).not_to include(future_commitment, expired_commitment, paused_commitment)
      end
    end
  end

  describe 'business methods' do
    let(:commitment) { create(:recurring_commitment,
                             recurrence_frequency: 'monthly',
                             start_date: Date.new(2024, 1, 15),
                             end_date: Date.new(2024, 12, 15),
                             default_amount: 500,
                             user: user,
                             category: category) }

    describe '#next_occurrence_date' do
      it 'calculates next occurrence for monthly frequency' do
        from_date = Date.new(2024, 3, 10)
        expect(commitment.next_occurrence_date(from_date)).to eq(Date.new(2024, 4, 10))
      end
      
      it 'calculates next occurrence for weekly frequency' do
        commitment.update(recurrence_frequency: 'weekly')
        from_date = Date.new(2024, 3, 10) # Sunday
        # next_week in Ruby goes to Monday of next week
        expect(commitment.next_occurrence_date(from_date)).to eq(Date.new(2024, 3, 11))
      end
      
      it 'calculates next occurrence for annual frequency' do
        commitment.update(recurrence_frequency: 'annual')
        from_date = Date.new(2024, 3, 10)
        expect(commitment.next_occurrence_date(from_date)).to eq(Date.new(2025, 3, 10))
      end
      
      it 'returns nil for closed commitments' do
        commitment.update(status: :closed)
        expect(commitment.next_occurrence_date).to be_nil
      end
      
      it 'returns nil when date is after end_date' do
        from_date = Date.new(2025, 1, 1)
        expect(commitment.next_occurrence_date(from_date)).to be_nil
      end
    end

    describe '#active_on?' do
      it 'returns true when active and on valid date' do
        date = Date.new(2024, 6, 15)
        expect(commitment.active_on?(date)).to be true
      end
      
      it 'returns false when before start date' do
        date = Date.new(2023, 12, 15)
        expect(commitment.active_on?(date)).to be false
      end
      
      it 'returns false when after end date' do
        date = Date.new(2025, 1, 15)
        expect(commitment.active_on?(date)).to be false
      end
      
      it 'returns false when status is not active' do
        commitment.update(status: :paused)
        date = Date.new(2024, 6, 15)
        expect(commitment.active_on?(date)).to be false
      end
      
      it 'works when end_date is nil' do
        commitment.update(end_date: nil)
        date = Date.new(2025, 6, 15)
        expect(commitment.active_on?(date)).to be true
      end
    end

    describe '#average_amount' do
      it 'returns default_amount when there are no transactions' do
        expect(commitment.average_amount).to eq(500)
      end
      
      it 'calculates average of confirmed transactions' do
        create(:transaction, :recurring, :confirmed, amount: 400, recurring_commitment: commitment, user: user)
        create(:transaction, :recurring, :confirmed, amount: 600, recurring_commitment: commitment, user: user)
        create(:transaction, :recurring, :pending, amount: 1000, recurring_commitment: commitment, user: user)
        
        expect(commitment.average_amount).to eq(500.0)
      end
      
      it 'returns zero when there are no transactions or default_amount' do
        commitment.update(default_amount: nil)
        expect(commitment.average_amount).to eq(0)
      end
    end

    describe '#amount_paid' do
      it 'sums only confirmed transactions' do
        create(:transaction, :recurring, :confirmed, amount: 300, recurring_commitment: commitment, user: user)
        create(:transaction, :recurring, :confirmed, amount: 200, recurring_commitment: commitment, user: user)
        create(:transaction, :recurring, :pending, amount: 100, recurring_commitment: commitment, user: user)
        
        expect(commitment.amount_paid).to eq(500)
      end
    end

    describe '#last_transaction' do
      it 'returns the last transaction by payment_date' do
        create(:transaction, :recurring, payment_date: 1.month.ago, recurring_commitment: commitment, user: user)
        newer_tx = create(:transaction, :recurring, payment_date: 1.week.ago, recurring_commitment: commitment, user: user)
        
        expect(commitment.last_transaction).to eq(newer_tx)
      end
    end

    describe '#next_expected_transaction' do
      it 'returns next future transaction' do
        create(:transaction, :recurring, payment_date: 1.week.ago, recurring_commitment: commitment, user: user)
        future_tx = create(:transaction, :recurring, payment_date: 1.week.from_now, recurring_commitment: commitment, user: user)
        
        expect(commitment.next_expected_transaction).to eq(future_tx)
      end
    end

    describe '#summary_status' do
      it 'returns expired when past end date' do
        commitment.update(end_date: 1.day.ago)
        expect(commitment.summary_status).to eq('expired')
      end
      
      it 'returns inactive when not active' do
        commitment.update(status: :paused, end_date: nil)
        expect(commitment.summary_status).to eq('inactive')
      end
      
      it 'returns not_started when not yet started' do
        commitment.update(start_date: 1.week.from_now, end_date: nil)
        expect(commitment.summary_status).to eq('not_started')
      end
      
      it 'returns active for active commitments in the period' do
        commitment.update(end_date: nil)
        expect(commitment.summary_status).to eq('active')
      end
    end

    describe '#generates_variable_expenses?' do
      it 'identifies variable expense commitments by name' do
        variable_commitment = create(:recurring_commitment, 
                                    name: 'Supermercado Mensal',
                                    user: user, 
                                    category: category)
        expect(variable_commitment.generates_variable_expenses?).to be true
      end
      
      it 'identifies variable expense commitments by category' do
        variable_category = create(:category, name: 'Farmácia', user: user)
        variable_commitment = create(:recurring_commitment,
                                    name: 'Medicamentos',
                                    user: user,
                                    category: variable_category)
        expect(variable_commitment.generates_variable_expenses?).to be true
      end
      
      it 'returns false for fixed commitments' do
        fixed_commitment = create(:recurring_commitment,
                                 name: 'Aluguel',
                                 user: user,
                                 category: category)
        expect(fixed_commitment.generates_variable_expenses?).to be false
      end
    end

    describe '#expense_analysis' do
      it 'calls analysis service when category is present' do
        allow(VariableExpenseAnalysisUnifiedService).to receive(:analyze_category).and_return({ average: 450, variance: 50 })
        
        result = commitment.expense_analysis(timeframe_months: 6)
        
        expect(VariableExpenseAnalysisUnifiedService).to have_received(:analyze_category).with(
          commitment.category,
          timeframe_months: 6
        )
        expect(result).to eq({ average: 450, variance: 50 })
      end
      
      it 'returns nil when category is not present' do
        commitment.update(category: nil)
        expect(commitment.expense_analysis).to be_nil
      end
    end
  end

  describe 'edge cases' do
    it 'handles start dates in the distant past' do
      old_commitment = build(:recurring_commitment,
                            start_date: 10.years.ago,
                            user: user,
                            category: category,
                            from_account: from_account,
                            to_account: to_account)
      expect(old_commitment).to be_valid
    end
    it 'handles end dates in the distant future' do
      long_commitment = build(:recurring_commitment,
                             start_date: Date.current,
                             end_date: 10.years.from_now,
                             user: user,
                             category: category,
                             from_account: from_account,
                             to_account: to_account)
      expect(long_commitment).to be_valid
    end
    it 'handles decimal values' do
      decimal_commitment = create(:recurring_commitment,
                                 default_amount: 999.99,
                                 user: user,
                                 category: category)
      expect(decimal_commitment.default_amount).to eq(999.99)
    end
    it 'handles long names' do
      long_name = 'a' * 255
      commitment = build(:recurring_commitment, name: long_name, user: user, category: category, from_account: from_account, to_account: to_account)
      expect(commitment).to be_valid
    end
    it 'handles long notes' do
      long_notes = 'a' * 1000
      commitment = build(:recurring_commitment, notes: long_notes, user: user, category: category, from_account: from_account, to_account: to_account)
      expect(commitment).to be_valid
    end
  end
end
