require "rails_helper"

RSpec.describe ReportsController, type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "authentication" do
    before { sign_out user }

    it "redirects unauthenticated users to sign in" do
      get reports_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "GET /reports" do
    it "returns http success for current month (default)" do
      get reports_path
      expect(response).to have_http_status(:ok)
    end

    it "accepts a specific month parameter" do
      get reports_path, params: { month: "2025-01" }
      expect(response).to have_http_status(:ok)
    end

    it "returns http success when there are transactions in the selected month" do
      category = create(:category, :expense, user: user)
      asset = create(:account, :asset, user: user)
      expense_dst = create(:account, :expense_destination, user: user)
      create(:transaction, :expense, user: user, category: category,
             from_account: asset, to_account: expense_dst,
             event_date: Date.current.beginning_of_month)
      get reports_path, params: { month: Date.current.strftime("%Y-%m") }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /reports/variable_expenses_analysis" do
    it "returns JSON when requested" do
      get variable_expenses_analysis_reports_path, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("application/json")
    end
  end
end
