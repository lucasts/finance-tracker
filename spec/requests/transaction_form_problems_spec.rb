require 'rails_helper'

RSpec.describe 'Transaction Form Problems', type: :request do
  let(:user) { create(:user) }
  
  before do
    # Sign in the user using Devise helpers
    post user_session_path, params: {
      user: {
        email: user.email,
        password: user.password
      }
    }
    
    # Create test accounts using existing factories and traits
    @bank_account = create(:account, :asset, name: 'Banco do Brasil', user: user)
    @credit_account = create(:account, :credit_card, name: 'Cartão Visa', user: user)
    @revenue_account = create(:account, :income_source, name: 'Salário Empresa', user: user)
    @expense_account = create(:account, :expense_destination, name: 'Supermercado ABC', user: user)
    
    # Create test categories
    @income_category = create(:category, :income, name: 'Salário', user: user)
    @expense_category = create(:category, :expense, name: 'Alimentação', user: user)
  end

  describe 'Problem 1: Installment plans creating future installments as paid' do
    it 'should create future installments with pending status - FIXED!' do
      # Create a transaction with installments using the correct parameter names
      transaction_params = {
        transaction: {
          transaction_type: 'expense',
          description: 'Compra parcelada teste',
          amount: 300.00,
          event_date: Date.current,
          payment_date: Date.current,
          from_account_id: @bank_account.id,
          to_account_id: @expense_account.id,
          category_id: @expense_category.id
        },
        create_installment_plan: "true",
        installments_count: 3
      }
      
      post transactions_path, params: transaction_params
      
      # Check response
      expect(response).to redirect_to(transactions_path)
      
      # Check that transactions were created with correct statuses
      transactions = Transaction.all.select { |t| t.description.include?("Compra parcelada teste") }.sort_by(&:event_date)
      expect(transactions.count).to eq(3)
      
      # PROBLEM 1 IS NOW FIXED: Future installments are correctly 'pending'
      expect(transactions.first.status).to eq('confirmed'), "First installment should be confirmed"
      expect(transactions.second.status).to eq('pending'), "Second installment should be pending"  
      expect(transactions.third.status).to eq('pending'), "Third installment should be pending"
      
      puts "✅ Problem 1 FIXED: Installment statuses are correct!"
    end
  end

  describe 'Problems 2 & 3: JavaScript form behavior issues' do
    it 'loads the transaction form and confirms it has the right structure' do
      get new_transaction_path
      
      expect(response).to have_http_status(:success)
      
      # Check that the form has the required JavaScript controller and targets
      expect(response.body).to include('data-controller="transaction-form"')
      expect(response.body).to include('data-transaction-form-target="categorySection"')
      expect(response.body).to include('data-transaction-form-target="transactionType"')
      expect(response.body).to include('data-transaction-form-target="fromAccount"')
      expect(response.body).to include('data-transaction-form-target="toAccount"')
      
      # Check that accounts and categories are loaded properly
      expect(assigns(:accounts)).to include(@bank_account, @credit_account, @revenue_account, @expense_account)
      expect(assigns(:categories)).to include(@income_category, @expense_category)
      
      puts "✅ Form structure is correct, but JavaScript issues need manual testing"
    end
  end
end
