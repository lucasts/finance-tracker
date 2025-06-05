require "test_helper"

class ImportSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
    
    @account = Account.create!(
      user: @user,
      name: "Test Account",
      account_type: AccountType.first || AccountType.create!(name: "Checking", description: "Test account type")
    )
    
    @category = Category.create!(
      user: @user,
      name: "Test Category",
      description: "Test category"
    )
    
    @import_session = ImportSession.create!(
      user: @user,
      account: @account,
      original_filename: "test.csv",
      raw_file: "test data",
      source_type: "csv"
    )
    
    # Create some imported transactions without reconciliation entries
    3.times do |i|
      ImportedTransaction.create!(
        import_session: @import_session,
        line_number: i + 1,
        raw_data: "test data #{i}",
        description: "Test Transaction #{i}",
        amount: (i + 1) * 100,
        event_date: Date.current,
        payment_date: Date.current,
        transaction_type: "expense"
      )
    end
  end

  test "should batch process pending transactions as create_new" do
    assert_difference('Transaction.count', 3) do
      assert_difference('ReconciliationEntry.count', 3) do
        post batch_process_pending_import_session_path(@import_session), 
             params: { action_type: 'create_new' },
             as: :json
      end
    end

    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert_equal 3, response_data['processed_count']
    assert_includes response_data['message'], '3 transação(ões) processada(s)'
  end

  test "should batch process pending transactions as ignore" do
    assert_no_difference('Transaction.count') do
      assert_difference('ReconciliationEntry.count', 3) do
        post batch_process_pending_import_session_path(@import_session), 
             params: { action_type: 'ignore' },
             as: :json
      end
    end

    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert_equal 3, response_data['processed_count']
    
    # Verify all reconciliation entries have 'ignore' action
    @import_session.imported_transactions.each do |tx|
      assert_equal 'ignore', tx.reconciliation_entry.action
    end
  end

  test "should handle empty pending transactions" do
    # Create reconciliation entries for all transactions first
    @import_session.imported_transactions.each do |tx|
      ReconciliationEntry.create!(
        imported_transaction: tx,
        action: 'ignore',
        user: @user,
        decided_at: Time.current
      )
    end

    post batch_process_pending_import_session_path(@import_session), 
         params: { action_type: 'create_new' },
         as: :json

    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert_not response_data['success']
    assert_includes response_data['message'], 'Não há transações pendentes'
  end
end
