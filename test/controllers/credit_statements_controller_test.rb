require "test_helper"

class CreditStatementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @credit_statement = credit_statements(:one)
  end

  test "should get index" do
    get credit_statements_url
    assert_response :success
  end

  test "should show credit_statement" do
    get credit_statement_url(@credit_statement)
    assert_response :success
  end

end
