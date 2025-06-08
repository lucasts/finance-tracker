require 'rails_helper'

RSpec.describe CreditStatement, type: :model do
  let(:user) { create(:user) }
  let(:credit_account_type) { AccountType.find_or_create_by!(code: 'CREDIT') { |at| at.assign_attributes(role: 'asset', name: 'Cartão de Crédito') } }
  let(:credit_account) { create(:account, account_type: credit_account_type, user: user) }
  let(:checking_account_type) { AccountType.find_or_create_by!(code: 'BANK') { |at| at.assign_attributes(role: 'asset', name: 'Conta Corrente') } }
  let(:checking_account) { create(:account, account_type: checking_account_type, user: user) }
  let(:expense_account_type) { AccountType.find_or_create_by!(code: 'EXPENSE') { |at| at.assign_attributes(role: 'expense', name: 'Despesa') } }
  let(:expense_account) { create(:account, account_type: expense_account_type, user: user) }
  let(:credit_statement) { create(:credit_statement, account: credit_account) }

  describe 'validations' do
    it { should validate_presence_of(:month) }
    it { should validate_presence_of(:amount_due) }
    it { should validate_presence_of(:amount_paid) }
    
    it 'validates month format' do
      expect(build(:credit_statement, month: '2024-01', account: credit_account)).to be_valid
      expect(build(:credit_statement, month: '2024-12', account: credit_account)).to be_valid
      
      expect(build(:credit_statement, month: '24-01', account: credit_account)).not_to be_valid
      expect(build(:credit_statement, month: '2024-1', account: credit_account)).not_to be_valid
      expect(build(:credit_statement, month: '2024/01', account: credit_account)).not_to be_valid
      expect(build(:credit_statement, month: 'janeiro-2024', account: credit_account)).not_to be_valid
    end
    
    it 'accepts valid statements' do
      statement = build(:credit_statement,
                       month: '2024-06',
                       amount_due: 1500.50,
                       amount_paid: 800.25,
                       due_on: Date.new(2024, 7, 10),
                       account: credit_account)
      expect(statement).to be_valid
    end
    
    it 'validates that account must be credit card' do
      statement = build(:credit_statement, account: checking_account)
      expect(statement).not_to be_valid
      expect(statement.errors[:account]).to include('deve ser uma conta do tipo cartão de crédito')
    end
  end

  describe 'associations' do
    it { should belong_to(:account) }
    it { should have_many(:transactions).dependent(:nullify) }
    
    it 'belongs to an account' do
      expect(credit_statement.account).to be_present
      expect(credit_statement.account).to be_a(Account)
    end
    
    it 'can have multiple transactions' do
      transaction1 = create(:transaction, credit_statement: credit_statement, user: user)
      transaction2 = create(:transaction, credit_statement: credit_statement, user: user)
      
      expect(credit_statement.transactions).to include(transaction1, transaction2)
      expect(credit_statement.transactions.count).to eq(2)
    end
    
    it 'nullifies transactions when deleted' do
      transaction = create(:transaction, credit_statement: credit_statement, user: user)
      
      expect { credit_statement.destroy }.to change(CreditStatement, :count).by(-1)
      expect(transaction.reload.credit_statement).to be_nil
    end
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(open: 0, paid: 1, overdue: 2) }
    
    it 'has default status as open' do
      statement = create(:credit_statement, account: credit_account)
      expect(statement.status).to eq('open')
    end
  end

  describe 'callbacks' do
    describe 'auto_update_status' do
      # Disable the update_amount_due callback for these tests to control exact values
      before do
        allow_any_instance_of(CreditStatement).to receive(:update_amount_due)
      end
      
      let(:statement) { create(:credit_statement, 
                              amount_due: 1000,
                              amount_paid: 0,
                              due_on: Date.current + 10.days,
                              status: :open,
                              account: credit_account) }

      it 'updates status to paid when amount paid >= amount due' do
        statement.update(amount_paid: 1000)
        expect(statement.status).to eq('paid')
        expect(statement.paid_on).to eq(Date.today)
      end
      
      it 'updates status to paid when amount paid > amount due' do
        statement.update(amount_paid: 1200)
        expect(statement.status).to eq('paid')
      end
      
      it 'updates status to overdue when due and not paid' do
        statement.update(due_on: Date.yesterday, amount_paid: -50)
        expect(statement.status).to eq('overdue')
      end
      
      it 'keeps status open when not yet due' do
        statement.update(amount_paid: 500, due_on: Date.tomorrow)
        statement.reload
        expect(statement.amount_due).to eq(1000)
        expect(statement.amount_paid).to eq(500)
        expect(statement.due_on).to eq(Date.tomorrow)
        expect(statement.status).to eq('open')
      end
      
      it 'does not change paid_on if already set' do
        original_paid_on = 5.days.ago.to_date
        statement.update(paid_on: original_paid_on, amount_paid: 1000)
        expect(statement.paid_on).to eq(original_paid_on)
      end
    end

    describe 'update_amount_due' do
      let(:statement) { create(:credit_statement, 
                              amount_due: 500,
                              account: credit_account) }

      it 'updates amount_due based on transaction sum' do
        create(:transaction, amount: 200, credit_statement: statement, user: user)
        create(:transaction, amount: 300, credit_statement: statement, user: user)
        create(:transaction, amount: 150, credit_statement: statement, user: user)
        
        statement.save
        expect(statement.reload.amount_due).to eq(650)
      end
      
      it 'does not update when sum equals current value' do
        statement.update(amount_due: 500)
        create(:transaction, amount: 250, credit_statement: statement, user: user, 
               from_account: statement.account, category: create(:category, user: user),
               event_date: Date.today, payment_date: Date.today, transaction_type: 'expense',
               description: 'Test transaction 1')
        create(:transaction, amount: 250, credit_statement: statement, user: user,
               from_account: statement.account, category: create(:category, user: user),
               event_date: Date.today, payment_date: Date.today, transaction_type: 'expense', 
               description: 'Test transaction 2')
        
        initial_amount = statement.reload.amount_due
        statement.touch # Trigger callbacks without changing anything
        expect(statement.reload.amount_due).to eq(initial_amount)
      end
    end
  end

  describe 'business methods' do
    describe '#remaining_balance' do
      it 'calculates remaining balance correctly' do
        statement = build(:credit_statement,
                          amount_due: 1000,
                          amount_paid: 300,
                          account: credit_account)
        # Use build and not save to avoid callbacks
        expect(statement.remaining_balance).to eq(700)
      end
      
      it 'returns negative value when overpaid' do
        statement = build(:credit_statement,
                          amount_due: 1000,
                          amount_paid: 1200,
                          account: credit_account)
        
        expect(statement.remaining_balance).to eq(-200)
      end
      
      it 'returns zero when fully paid' do
        statement = build(:credit_statement,
                          amount_due: 1000,
                          amount_paid: 1000,
                          account: credit_account)
        
        expect(statement.remaining_balance).to eq(0)
      end
    end
  end

  describe 'account validation' do
    it 'allows only credit card accounts' do
      valid_statement = build(:credit_statement, account: credit_account)
      invalid_statement = build(:credit_statement, account: checking_account)
      
      expect(valid_statement).to be_valid
      expect(invalid_statement).not_to be_valid
    end
    
    it 'works when account_type is nil' do
      # Tests validation method directly
      statement = build(:credit_statement, account: credit_account)
      statement.account.account_type = nil
      expect(statement).not_to be_valid
      expect(statement.errors[:account]).to include("deve ser uma conta do tipo cartão de crédito")
    end
  end

  describe 'edge cases' do
    it 'handles decimal values' do
      # Disable the update_amount_due callback for this test
      allow_any_instance_of(CreditStatement).to receive(:update_amount_due)
      
      statement = create(:credit_statement,
                        amount_due: 999.99,
                        amount_paid: 555.55,
                        account: credit_account)
      
      expect(statement.remaining_balance).to be_within(0.01).of(444.44)
    end
    
    it 'handles zero values' do
      statement = create(:credit_statement,
                        amount_due: 0,
                        amount_paid: 0,
                        account: credit_account)
      
      expect(statement.remaining_balance).to eq(0)
      expect(statement.status).to eq('paid')
    end
    
    it 'handles months in distant past' do
      old_statement = build(:credit_statement,
                           month: '2020-01',
                           account: credit_account)
      expect(old_statement).to be_valid
    end
    
    it 'handles future months' do
      future_statement = build(:credit_statement,
                              month: '2025-12',
                              account: credit_account)
      expect(future_statement).to be_valid
    end
    
    it 'handles extreme due dates' do
      past_statement = create(:credit_statement,
                             due_on: 10.years.ago,
                             month: '2014-01',
                             account: credit_account)
      
      # Create another account to avoid unique constraint
      credit_account2 = create(:account, user: user, account_type: credit_account.account_type)
      future_statement = create(:credit_statement,
                               due_on: 10.years.from_now,
                               month: '2035-01',
                               account: credit_account2)
      
      expect(past_statement).to be_valid
      expect(future_statement).to be_valid
    end
  end

  describe 'transaction integration' do
    let(:statement) { create(:credit_statement, 
                            amount_due: 0,
                            account: credit_account) }

    it 'updates amount_due when transactions are added' do
      create(:transaction, amount: 100, credit_statement: statement, user: user)
      statement.save
      expect(statement.reload.amount_due).to eq(100)
      
      create(:transaction, amount: 50, credit_statement: statement, user: user)
      statement.save
      expect(statement.reload.amount_due).to eq(150)
    end
    
    it 'updates status automatically based on payments' do
      statement.update(amount_due: 200, amount_paid: 0)
      expect(statement.status).to eq('open')
      
      statement.update(amount_paid: 200)
      expect(statement.status).to eq('paid')
    end
  end
end
