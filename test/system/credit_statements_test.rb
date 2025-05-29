require "application_system_test_case"

class CreditStatementsTest < ApplicationSystemTestCase
  setup do
    @credit_statement = credit_statements(:one)
  end

  test "visiting the index" do
    visit credit_statements_url
    assert_selector "h1", text: "Credit statements"
  end

end
