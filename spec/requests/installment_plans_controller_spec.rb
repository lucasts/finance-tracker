require "rails_helper"

RSpec.describe InstallmentPlansController, type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:category) { create(:category, :expense, user: user) }
  let(:from_account) { create(:account, :asset, user: user) }
  let(:to_account) { create(:account, :expense_destination, user: user) }

  before { sign_in user }

  describe "authentication" do
    before { sign_out user }

    it "redirects unauthenticated users to sign in" do
      get installment_plans_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "user data isolation" do
    it "returns 404 for another user's installment plan" do
      other_category = create(:category, :expense, user: other_user)
      other_from = create(:account, :asset, user: other_user)
      other_to = create(:account, :expense_destination, user: other_user)
      other_plan = create(:installment_plan, user: other_user,
                          category: other_category,
                          from_account: other_from,
                          to_account: other_to)
      get installment_plan_path(other_plan)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /installment_plans" do
    it "returns http success" do
      get installment_plans_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /installment_plans/:id" do
    let!(:plan) do
      create(:installment_plan, user: user, category: category,
             from_account: from_account, to_account: to_account)
    end

    it "returns http success" do
      get installment_plan_path(plan)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /installment_plans/new" do
    it "returns http success" do
      get new_installment_plan_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /installment_plans" do
    let(:valid_params) do
      {
        installment_plan: {
          name: "Laptop 12x",
          total_amount: "3600.00",
          installment_count: 12,
          starts_on: Date.current.to_s,
          recurrence_frequency: "monthly",
          status: "active",
          category_id: category.id,
          from_account_id: from_account.id,
          to_account_id: to_account.id
        }
      }
    end

    context "with valid params" do
      it "creates an installment plan and redirects" do
        expect {
          post installment_plans_path, params: valid_params
        }.to change(InstallmentPlan, :count).by(1)
        expect(response).to redirect_to(installment_plan_path(InstallmentPlan.last))
      end
    end

    context "with invalid params" do
      it "re-renders new with unprocessable_content status" do
        post installment_plans_path,
             params: { installment_plan: { name: "" } }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "with a category_id from another user" do
      let(:other_category) { create(:category, :expense, user: other_user) }

      it "returns bad_request for unauthorized category" do
        post installment_plans_path, params: valid_params.deep_merge(
          installment_plan: { category_id: other_category.id }
        )
        expect(response).to have_http_status(:bad_request)
      end
    end
  end

  describe "PATCH /installment_plans/:id" do
    let!(:plan) do
      create(:installment_plan, user: user, category: category,
             from_account: from_account, to_account: to_account)
    end

    context "with valid params" do
      it "updates the plan and redirects" do
        patch installment_plan_path(plan),
              params: { installment_plan: { name: "Updated Plan Name" } }
        expect(response).to redirect_to(installment_plan_path(plan))
        expect(plan.reload.name).to eq("Updated Plan Name")
      end
    end

    context "with invalid params" do
      it "re-renders edit with unprocessable_content status" do
        patch installment_plan_path(plan),
              params: { installment_plan: { name: "", total_amount: nil, installment_count: nil } }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /installment_plans/:id" do
    let!(:plan) do
      create(:installment_plan, user: user, category: category,
             from_account: from_account, to_account: to_account)
    end

    it "closes the plan (soft delete) and redirects" do
      delete installment_plan_path(plan)
      expect(response).to redirect_to(installment_plans_path)
      expect(plan.reload.status).to eq("closed")
    end
  end

  describe "PATCH /installment_plans/:id/toggle_active" do
    let!(:plan) do
      create(:installment_plan, user: user, category: category,
             from_account: from_account, to_account: to_account, status: :active)
    end

    it "toggles the plan to paused status and redirects" do
      patch toggle_active_installment_plan_path(plan)
      expect(response).to redirect_to(installment_plans_path)
      expect(plan.reload.status).to eq("paused")
    end
  end

  describe "GET /installment_plans/:id/payment_schedule" do
    let!(:plan) do
      create(:installment_plan, user: user, category: category,
             from_account: from_account, to_account: to_account,
             installment_count: 3, total_amount: 300)
    end

    it "returns a JSON payment schedule" do
      get payment_schedule_installment_plan_path(plan), as: :json
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("application/json")
      body = response.parsed_body
      expect(body["schedule"].length).to eq(3)
    end
  end
end
