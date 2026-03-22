require "rails_helper"

RSpec.describe RecurringCommitmentsController, type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:category) { create(:category, :expense, user: user) }
  let(:from_account) { create(:account, :asset, user: user) }
  let(:to_account) { create(:account, :expense_destination, user: user) }

  before { sign_in user }

  describe "authentication" do
    before { sign_out user }

    it "redirects unauthenticated users to sign in" do
      get recurring_commitments_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "user data isolation" do
    it "returns 404 for another user's commitment" do
      other_category = create(:category, :expense, user: other_user)
      other_from = create(:account, :asset, user: other_user)
      other_to = create(:account, :expense_destination, user: other_user)
      other_commitment = create(:recurring_commitment, user: other_user,
                                category: other_category,
                                from_account: other_from,
                                to_account: other_to)
      get recurring_commitment_path(other_commitment)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /recurring_commitments" do
    it "returns http success" do
      get recurring_commitments_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /recurring_commitments/:id" do
    let!(:commitment) { create(:recurring_commitment, user: user, category: category, from_account: from_account, to_account: to_account) }

    it "returns http success" do
      get recurring_commitment_path(commitment)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /recurring_commitments/new" do
    it "returns http success" do
      get new_recurring_commitment_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /recurring_commitments" do
    let(:valid_params) do
      {
        recurring_commitment: {
          name: "Netflix",
          recurrence_frequency: "monthly",
          start_date: Date.current.to_s,
          default_amount: "29.90",
          status: "active",
          from_account_id: from_account.id,
          to_account_id: to_account.id,
          category_id: category.id
        }
      }
    end

    context "with valid params" do
      it "creates a recurring commitment and redirects" do
        expect {
          post recurring_commitments_path, params: valid_params
        }.to change(RecurringCommitment, :count).by(1)
        expect(response).to redirect_to(recurring_commitment_path(RecurringCommitment.last))
      end
    end

    context "with invalid params" do
      it "re-renders new with unprocessable_content status" do
        post recurring_commitments_path,
             params: { recurring_commitment: { name: "" } }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "with a foreign account_id from another user" do
      let(:other_from) { create(:account, :asset, user: other_user) }

      it "returns bad_request for unauthorized account" do
        post recurring_commitments_path, params: valid_params.deep_merge(
          recurring_commitment: { from_account_id: other_from.id }
        )
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe "PATCH /recurring_commitments/:id" do
    let!(:commitment) { create(:recurring_commitment, user: user, category: category, from_account: from_account, to_account: to_account) }

    context "with valid params" do
      it "updates the commitment and redirects" do
        patch recurring_commitment_path(commitment),
              params: { recurring_commitment: { name: "Updated Name" } }
        expect(response).to redirect_to(recurring_commitment_path(commitment))
        expect(commitment.reload.name).to eq("Updated Name")
      end
    end
  end

  describe "DELETE /recurring_commitments/:id" do
    let!(:commitment) { create(:recurring_commitment, user: user, category: category, from_account: from_account, to_account: to_account) }

    it "closes (deactivates) the commitment and redirects" do
      delete recurring_commitment_path(commitment)
      expect(response).to redirect_to(recurring_commitments_path)
      expect(commitment.reload.status).to eq("closed")
    end
  end

  describe "PATCH /recurring_commitments/:id/toggle_active" do
    let!(:commitment) { create(:recurring_commitment, user: user, category: category, from_account: from_account, to_account: to_account, status: :active) }

    it "toggles the status to paused and redirects" do
      patch toggle_active_recurring_commitment_path(commitment)
      expect(response).to redirect_to(recurring_commitments_path)
      expect(commitment.reload.status).to eq("paused")
    end
  end

  describe "GET /recurring_commitments/:id/timeline" do
    let!(:commitment) { create(:recurring_commitment, user: user, category: category, from_account: from_account, to_account: to_account) }

    it "returns JSON" do
      get timeline_recurring_commitment_path(commitment), as: :json
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("application/json")
    end
  end
end
