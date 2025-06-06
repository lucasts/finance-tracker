require 'rails_helper'

RSpec.describe InstallmentPlan, type: :model do
  let(:user) { create(:user) }
  let(:installment_plan) { create(:installment_plan, user: user) }

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:installment_count) }
    it { should validate_presence_of(:recurrence_frequency) }
    it { should validate_presence_of(:starts_on) }
    it { should validate_presence_of(:status) }
    
    it { should validate_numericality_of(:installment_count)
           .is_greater_than(0)
           .is_less_than_or_equal_to(120) }
    
    it { should validate_numericality_of(:total_amount)
           .is_greater_than(0) }
    
    it { should validate_inclusion_of(:recurrence_frequency)
           .in_array(%w[weekly monthly quarterly annual]) }
    
    it 'accepts valid plans' do
      plan = build(:installment_plan, 
                   name: 'Geladeira 12x',
                   installment_count: 12,
                   total_amount: 2400,
                   starts_on: Date.current,
                   recurrence_frequency: 'monthly',
                   user: user)
      expect(plan).to be_valid
    end
    
    it 'rejects invalid installment count' do
      expect(build(:installment_plan, installment_count: 0, user: user)).not_to be_valid
      expect(build(:installment_plan, installment_count: -1, user: user)).not_to be_valid
      expect(build(:installment_plan, installment_count: 150, user: user)).not_to be_valid
    end
    
    it 'rejects invalid frequency' do
      expect(build(:installment_plan, recurrence_frequency: 'daily', user: user)).not_to be_valid
      expect(build(:installment_plan, recurrence_frequency: 'invalid', user: user)).not_to be_valid
    end
  end

  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:transactions).dependent(:nullify) }
    
    it 'belongs to a user' do
      expect(installment_plan.user).to be_present
      expect(installment_plan.user).to be_a(User)
    end
    
    it 'can have multiple transactions' do
      transaction1 = create(:transaction, :installment, installment_plan: installment_plan, user: user)
      transaction2 = create(:transaction, :installment, installment_plan: installment_plan, user: user)
      
      expect(installment_plan.transactions).to include(transaction1, transaction2)
      expect(installment_plan.transactions.count).to eq(2)
    end
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(active: 0, paused: 1, closed: 2) }
    
    it 'has default status as active' do
      plan = create(:installment_plan, user: user)
      expect(plan.status).to eq('active')
    end
  end

  describe 'scopes' do
    let!(:active_plan) { create(:installment_plan, status: :active, user: user) }
    let!(:paused_plan) { create(:installment_plan, status: :paused, user: user) }
    let!(:closed_plan) { create(:installment_plan, status: :closed, user: user) }
    let!(:weekly_plan) { create(:installment_plan, recurrence_frequency: 'weekly', user: user) }
    let!(:monthly_plan) { create(:installment_plan, recurrence_frequency: 'monthly', user: user) }

    describe '.active_plans' do
      it 'returns only active plans' do
        expect(InstallmentPlan.active_plans).to include(active_plan)
        expect(InstallmentPlan.active_plans).not_to include(paused_plan, closed_plan)
      end
    end

    describe '.by_frequency' do
      it 'filters by frequency' do
        expect(InstallmentPlan.by_frequency('weekly')).to include(weekly_plan)
        expect(InstallmentPlan.by_frequency('monthly')).to include(monthly_plan)
        expect(InstallmentPlan.by_frequency('monthly')).not_to include(weekly_plan)
      end
    end

    describe '.monthly_plans' do
      it 'returns only monthly plans' do
        monthly_plans = InstallmentPlan.monthly_plans
        expect(monthly_plans.map(&:recurrence_frequency).uniq).to eq(['monthly'])
      end
    end

    describe '.with_pending_installments' do
      it 'returns plans with pending installments' do
        plan_with_pending = create(:installment_plan, status: :active, user: user)
        create(:transaction, :installment, :pending, installment_plan: plan_with_pending, user: user)
        
        plan_without_pending = create(:installment_plan, status: :active, user: user)
        
        result = InstallmentPlan.with_pending_installments
        expect(result).to include(plan_with_pending)
        expect(result).not_to include(plan_without_pending)
      end
    end
  end

  describe 'business methods' do
    let(:plan) { create(:installment_plan, 
                       installment_count: 12, 
                       total_amount: 2400,
                       starts_on: Date.current.beginning_of_month,
                       recurrence_frequency: 'monthly',
                       user: user) }

    describe '#installment_amount' do
      it 'calculates installment amount correctly' do
        expect(plan.installment_amount).to eq(200.0)
      end
      
      it 'returns zero when total_amount is nil' do
        plan.update(total_amount: nil)
        expect(plan.installment_amount).to eq(0)
      end
      
      it 'returns zero when installment_count is zero' do
        plan.update(installment_count: 0)
        expect(plan.installment_amount).to eq(0)
      end
      
      it 'rounds to 2 decimal places' do
        plan.update(total_amount: 1000, installment_count: 3)
        expect(plan.installment_amount).to eq(333.33)
      end
    end

    describe '#next_installment_date' do
      it 'calculates next date for monthly frequency' do
        plan.update(recurrence_frequency: 'monthly', starts_on: Date.new(2024, 1, 15))
        
        expect(plan.next_installment_date(1)).to eq(Date.new(2024, 1, 15))
        expect(plan.next_installment_date(2)).to eq(Date.new(2024, 2, 15))
        expect(plan.next_installment_date(12)).to eq(Date.new(2024, 12, 15))
      end
      
      it 'calculates next date for weekly frequency' do
        plan.update(recurrence_frequency: 'weekly', starts_on: Date.new(2024, 1, 15))
        
        expect(plan.next_installment_date(1)).to eq(Date.new(2024, 1, 15))
        expect(plan.next_installment_date(2)).to eq(Date.new(2024, 1, 22))
        expect(plan.next_installment_date(4)).to eq(Date.new(2024, 2, 5))
      end
      
      it 'calculates next date for quarterly frequency' do
        plan.update(recurrence_frequency: 'quarterly', starts_on: Date.new(2024, 1, 15))
        
        expect(plan.next_installment_date(1)).to eq(Date.new(2024, 1, 15))
        expect(plan.next_installment_date(2)).to eq(Date.new(2024, 4, 15))
        expect(plan.next_installment_date(3)).to eq(Date.new(2024, 7, 15))
      end
      
      it 'calculates next date for annual frequency' do
        plan.update(recurrence_frequency: 'annual', starts_on: Date.new(2024, 1, 15))
        
        expect(plan.next_installment_date(1)).to eq(Date.new(2024, 1, 15))
        expect(plan.next_installment_date(2)).to eq(Date.new(2025, 1, 15))
      end
      
      it 'returns nil for installment beyond limit' do
        expect(plan.next_installment_date(13)).to be_nil
      end
    end

    describe '#amount_paid' do
      it 'sums only confirmed transactions' do
        create(:transaction, :installment, :confirmed, amount: 200, installment_plan: plan, user: user)
        create(:transaction, :installment, :confirmed, amount: 200, installment_plan: plan, user: user)
        create(:transaction, :installment, :pending, amount: 200, installment_plan: plan, user: user)
        
        expect(plan.amount_paid).to eq(400)
      end
    end

    describe '#amount_pending' do
      it 'calculates pending amount correctly' do
        plan.update(total_amount: 1000)
        create(:transaction, :installment, :confirmed, amount: 300, installment_plan: plan, user: user)
        
        expect(plan.amount_pending).to eq(700)
      end
      
      it 'returns zero when total_amount is nil' do
        plan.update(total_amount: nil)
        expect(plan.amount_pending).to eq(0)
      end
    end

    describe '#percentage_paid' do
      it 'calculates percentage paid correctly' do
        plan.update(total_amount: 1000)
        create(:transaction, :installment, :confirmed, amount: 250, installment_plan: plan, user: user)
        
        expect(plan.percentage_paid).to eq(25.0)
      end
      
      it 'returns zero when total_amount is zero or nil' do
        plan.update(total_amount: 0)
        expect(plan.percentage_paid).to eq(0)
        
        plan.update(total_amount: nil)
        expect(plan.percentage_paid).to eq(0)
      end
    end

    describe '#installments_paid' do
      it 'counts confirmed installments' do
        create(:transaction, :installment, :confirmed, installment_plan: plan, user: user)
        create(:transaction, :installment, :confirmed, installment_plan: plan, user: user)
        create(:transaction, :installment, :pending, installment_plan: plan, user: user)
        
        expect(plan.installments_paid).to eq(2)
      end
    end

    describe '#installments_pending' do
      it 'calculates pending installments' do
        plan.update(installment_count: 10)
        create(:transaction, :installment, :confirmed, installment_plan: plan, user: user)
        create(:transaction, :installment, :confirmed, installment_plan: plan, user: user)
        
        expect(plan.installments_pending).to eq(8)
      end
    end

    describe '#summary_status' do
      it 'returns completed when all installments are paid' do
        plan.update(installment_count: 2)
        create(:transaction, :installment, :confirmed, installment_plan: plan, user: user)
        create(:transaction, :installment, :confirmed, installment_plan: plan, user: user)
        
        expect(plan.summary_status).to eq('completed')
      end
      
      it 'returns in_progress when some installments are paid' do
        plan.update(installment_count: 3)
        create(:transaction, :installment, :confirmed, installment_plan: plan, user: user)
        
        expect(plan.summary_status).to eq('in_progress')
      end
      
      it 'returns not_started when no installments are paid' do
        expect(plan.summary_status).to eq('not_started')
      end
    end
  end

  describe 'edge cases' do
    it 'handles long-term plans' do
      long_plan = build(:installment_plan, 
                       installment_count: 120,
                       starts_on: Date.current,
                       user: user)
      expect(long_plan).to be_valid
    end
    
    it 'handles decimal values' do
      plan = create(:installment_plan, 
                   total_amount: 999.99,
                   installment_count: 3,
                   user: user)
      expect(plan.installment_amount).to eq(333.33)
    end
    
    it 'handles past dates' do
      past_plan = build(:installment_plan, 
                       starts_on: 1.year.ago,
                       user: user)
      expect(past_plan).to be_valid
    end
    
    it 'handles long names' do
      long_name = 'a' * 255
      plan = build(:installment_plan, name: long_name, user: user)
      expect(plan).to be_valid
    end
  end
end
