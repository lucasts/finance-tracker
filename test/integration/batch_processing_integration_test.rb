require "test_helper"

class BatchProcessingIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    # Create a test user (since we might not have devise fixtures)
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    
    # Create account type and account
    @account_type = AccountType.create!(name: "Checking", description: "Test account type")
    @account = Account.create!(
      user: @user,
      name: "Test Account",
      account_type: @account_type
    )
    
    # Create category
    @category = Category.create!(
      user: @user,
      name: "Test Category",
      description: "Test category"
    )
    
    # Create import session
    @import_session = ImportSession.create!(
      user: @user,
      account: @account,
      original_filename: "test.csv",
      raw_file: "date,description,amount\n2024-01-01,Test 1,-100\n2024-01-02,Test 2,-200",
      source_type: "csv"
    )
    
    # Create pending imported transactions
    @pending_tx1 = ImportedTransaction.create!(
      import_session: @import_session,
      line_number: 1,
      raw_data: "2024-01-01,Test 1,-100",
      description: "Test Transaction 1",
      amount: -100,
      event_date: Date.parse("2024-01-01"),
      payment_date: Date.parse("2024-01-01"),
      transaction_type: "expense"
    )
    
    @pending_tx2 = ImportedTransaction.create!(
      import_session: @import_session,
      line_number: 2,
      raw_data: "2024-01-02,Test 2,-200",
      description: "Test Transaction 2",
      amount: -200,
      event_date: Date.parse("2024-01-02"),
      payment_date: Date.parse("2024-01-02"),
      transaction_type: "expense"
    )
  end

  test "batch processing creates transactions and reconciliation entries" do
    # Verify initial state
    assert_equal 0, Transaction.count
    assert_equal 0, ReconciliationEntry.count
    assert_equal 2, @import_session.imported_transactions.count
    
    # Sign in user
    post "/users/sign_in", params: { 
      user: { email: @user.email, password: "password123" } 
    }
    
    # Make batch processing request
    post "/import_sessions/#{@import_session.id}/batch_process_pending", 
         params: { action_type: 'create_new' },
         headers: { 'Content-Type' => 'application/json' }
    
    assert_response :success
    
    # Parse response
    response_data = JSON.parse(response.body)
    assert response_data['success'], "Expected success but got: #{response_data}"
    assert_equal 2, response_data['processed_count']
    
    # Verify transactions were created
    assert_equal 2, Transaction.count
    assert_equal 2, ReconciliationEntry.count
    
    # Verify reconciliation entries are linked correctly
    @import_session.imported_transactions.each do |imported_tx|
      rec_entry = imported_tx.reconciliation_entry
      assert_not_nil rec_entry
      assert_equal 'create_new', rec_entry.action
      assert_not_nil rec_entry.linked_transaction
      assert_equal @user, rec_entry.user
    end
  end

  test "batch processing ignore creates reconciliation entries without transactions" do
    # Sign in user
    post "/users/sign_in", params: { 
      user: { email: @user.email, password: "password123" } 
    }
    
    # Make batch processing request to ignore
    post "/import_sessions/#{@import_session.id}/batch_process_pending", 
         params: { action_type: 'ignore' },
         headers: { 'Content-Type' => 'application/json' }
    
    assert_response :success
    
    # Parse response
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert_equal 2, response_data['processed_count']
    
    # Verify no transactions were created but reconciliation entries exist
    assert_equal 0, Transaction.count
    assert_equal 2, ReconciliationEntry.count
    
    # Verify all reconciliation entries have 'ignore' action
    @import_session.imported_transactions.each do |imported_tx|
      rec_entry = imported_tx.reconciliation_entry
      assert_not_nil rec_entry
      assert_equal 'ignore', rec_entry.action
      assert_nil rec_entry.linked_transaction
    end
  end
end
