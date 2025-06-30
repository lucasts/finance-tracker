require 'rails_helper'

RSpec.describe CreditStatementService, type: :service do
  let(:user) { create(:user) }
  let(:credit_account_type) { AccountType.find_or_create_by!(code: 'CREDIT_CARD') { |at| at.assign_attributes(role: 'asset', name: 'Cartão de Crédito') } }
  let(:credit_account) { create(:account, account_type: credit_account_type, user: user, closing_day: 15, due_day: 5) }
  let(:expense_account_type) { AccountType.find_or_create_by!(code: 'EXPENSE') { |at| at.assign_attributes(role: 'expense', name: 'Despesa') } }
  let(:expense_account) { create(:account, account_type: expense_account_type, user: user) }
  let(:category) { create(:category, user: user) }

  describe '.find_or_create_for_transaction' do
    let(:transaction) do
      create(:transaction,
             from_account: credit_account,
             to_account: expense_account,
             category: category,
             user: user,
             event_date: Date.new(2024, 6, 10))
    end

    it 'creates a new credit statement when none exists' do
      expect {
        CreditStatementService.find_or_create_for_transaction(transaction)
      }.to change(CreditStatement, :count).by(1)
    end

    it 'returns existing credit statement when one exists' do
      existing_statement = create(:credit_statement, account: credit_account, month: '2024-06')
      
      result = CreditStatementService.find_or_create_for_transaction(transaction)
      
      expect(result).to eq(existing_statement)
      expect(CreditStatement.count).to eq(1)
    end

    it 'calculates correct period based on closing day' do
      # Transaction on June 10th, closing day is 15th, so should be in June statement
      result = CreditStatementService.find_or_create_for_transaction(transaction)
      expect(result.month).to eq('2024-06')
    end

    it 'calculates correct period after closing day' do
      # Transaction on June 20th, closing day is 15th, so should be in July statement
      transaction.update!(event_date: Date.new(2024, 6, 20))
      result = CreditStatementService.find_or_create_for_transaction(transaction)
      expect(result.month).to eq('2024-07')
    end

    it 'returns nil for non-credit card transactions' do
      bank_account_type = AccountType.find_or_create_by!(code: 'BANK') { |at| at.assign_attributes(role: 'asset', name: 'Conta Corrente') }
      bank_account = create(:account, account_type: bank_account_type, user: user)
      transaction.update!(from_account: bank_account)
      
      result = CreditStatementService.find_or_create_for_transaction(transaction)
      expect(result).to be_nil
    end

    it 'sets proper default values for new statements' do
      result = CreditStatementService.find_or_create_for_transaction(transaction)
      
      # When a statement is created for an existing transaction, 
      # it should include that transaction's amount in amount_due
      expect(result.amount_due).to eq(transaction.amount)
      expect(result.amount_paid).to eq(0.0)
      expect(result.status).to eq('open')
      expect(result.closed_on).to eq(Date.new(2024, 6, 15))
      expect(result.due_on).to eq(Date.new(2024, 7, 5))
    end
  end

  describe '.calculate_periods_for_installment' do
    it 'calculates correct periods for monthly installments' do
      start_date = Date.new(2024, 6, 10)
      periods = CreditStatementService.calculate_periods_for_installment(start_date, 3, 'monthly')
      
      expect(periods).to eq(['2024-06', '2024-07', '2024-08'])
    end

    it 'calculates correct periods for weekly installments' do
      start_date = Date.new(2024, 6, 10)
      periods = CreditStatementService.calculate_periods_for_installment(start_date, 3, 'weekly')
      
      expect(periods).to eq(['2024-06', '2024-06', '2024-06'])
    end
  end

  describe '.ensure_statements_for_periods' do
    it 'creates multiple statements for different periods' do
      periods = ['2024-06', '2024-07', '2024-08']
      
      expect {
        CreditStatementService.ensure_statements_for_periods(credit_account, periods)
      }.to change(CreditStatement, :count).by(3)
    end

    it 'does not create duplicates for existing periods' do
      create(:credit_statement, account: credit_account, month: '2024-06')
      periods = ['2024-06', '2024-07']
      
      expect {
        CreditStatementService.ensure_statements_for_periods(credit_account, periods)
      }.to change(CreditStatement, :count).by(1)
    end
  end

  describe '.create_future_statements' do
    it 'creates statements for future months' do
      expect {
        CreditStatementService.create_future_statements(credit_account, 3)
      }.to change(CreditStatement, :count).by(4) # Current month + 3 future months
    end

    it 'returns empty array for non-credit accounts' do
      bank_account_type = AccountType.find_or_create_by!(code: 'BANK') { |at| at.assign_attributes(role: 'asset', name: 'Conta Corrente') }
      bank_account = create(:account, account_type: bank_account_type, user: user)
      
      result = CreditStatementService.create_future_statements(bank_account, 3)
      expect(result).to eq([])
    end
  end
end
