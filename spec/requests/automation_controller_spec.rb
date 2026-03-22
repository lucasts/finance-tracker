require "rails_helper"

RSpec.describe AutomationController, type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "authentication" do
    before { sign_out user }

    it "redirects unauthenticated users to sign in" do
      get automation_index_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "GET /automation" do
    it "returns http success" do
      get automation_index_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /automation/run_daily" do
    before { allow(AutomationJob).to receive(:perform_later) }

    it "enqueues AutomationJob and redirects" do
      post run_daily_automation_index_path
      expect(AutomationJob).to have_received(:perform_later)
      expect(response).to redirect_to(automation_index_path)
    end

    it "accepts a test_date parameter" do
      post run_daily_automation_index_path, params: { test_date: "2025-06-01" }
      expect(AutomationJob).to have_received(:perform_later).with(%w[recurring installments], Date.new(2025, 6, 1))
      expect(response).to redirect_to(automation_index_path)
    end
  end

  describe "POST /automation/run_recurring" do
    before { allow(AutomationJob).to receive(:perform_later) }

    it "enqueues AutomationJob for recurring and redirects" do
      post run_recurring_automation_index_path
      expect(AutomationJob).to have_received(:perform_later).with(%w[recurring], anything)
      expect(response).to redirect_to(automation_index_path)
    end
  end

  describe "POST /automation/run_installments" do
    before { allow(AutomationJob).to receive(:perform_later) }

    it "enqueues AutomationJob for installments and redirects" do
      post run_installments_automation_index_path
      expect(AutomationJob).to have_received(:perform_later).with(%w[installments], anything)
      expect(response).to redirect_to(automation_index_path)
    end
  end

  describe "GET /automation/preview" do
    it "returns http success" do
      get preview_automation_index_path
      expect(response).to have_http_status(:ok)
    end

    it "returns JSON when requested" do
      get preview_automation_index_path, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("application/json")
    end
  end

  describe "GET /automation/status" do
    it "returns JSON with status info" do
      get status_automation_index_path
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["status"]).to eq("completed")
    end
  end
end
