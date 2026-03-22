require "rails_helper"

RSpec.describe ReconciliationEntriesController, type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "authentication" do
    before { sign_out user }

    it "redirects unauthenticated users to sign in" do
      post reconciliation_entries_path, params: {}
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "POST /reconciliation_entries" do
    it "responds without server error (action is a stub)" do
      # The create action is currently a no-op stub; it should not 500
      post reconciliation_entries_path, params: { reconciliation_entry: {} }
      expect(response.status).not_to eq(500)
    end
  end
end
