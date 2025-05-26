require "test_helper"

class OverviewControllerTest < ActionDispatch::IntegrationTest
  test "should get overview for current period" do
    get overview_index_path(period: "2025-05")
    assert_response :success
    assert_select "h1", /Resumo de/
  end
end