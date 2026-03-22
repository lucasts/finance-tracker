require "rails_helper"

RSpec.describe AccountTypesController, type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "authentication" do
    before { sign_out user }

    it "redirects unauthenticated users to sign in" do
      get account_types_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "GET /account_types" do
    it "returns http success" do
      get account_types_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /account_types/new" do
    it "returns http success" do
      get new_account_type_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /account_types" do
    context "with valid params" do
      let(:valid_params) { { account_type: { name: "Poupança", code: "SAVINGS_TEST", role: "asset" } } }

      it "creates an account type and redirects" do
        expect {
          post account_types_path, params: valid_params
        }.to change(AccountType, :count).by(1)
        expect(response).to redirect_to(account_types_path)
      end
    end

    context "with invalid params" do
      it "re-renders new with unprocessable_entity status" do
        post account_types_path, params: { account_type: { name: "", code: "", role: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /account_types/:id/edit" do
    let(:account_type) { AccountType.find_by(code: "CHECKING") || create(:account_type) }

    it "returns http success" do
      get edit_account_type_path(account_type)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /account_types/:id" do
    let!(:account_type) { AccountType.create!(name: "Test Edit Type", code: "EDIT_TEST", role: "asset") }

    context "with valid params" do
      it "updates account type and redirects" do
        patch account_type_path(account_type), params: { account_type: { name: "Updated Name" } }
        expect(response).to redirect_to(account_types_path)
        expect(account_type.reload.name).to eq("Updated Name")
      end
    end

    context "with invalid params" do
      it "re-renders edit with unprocessable_entity status" do
        patch account_type_path(account_type), params: { account_type: { name: "", role: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /account_types/:id" do
    let!(:account_type) { AccountType.create!(name: "To Delete", code: "DELETE_TEST", role: "asset") }

    it "destroys the account type and redirects" do
      expect {
        delete account_type_path(account_type)
      }.to change(AccountType, :count).by(-1)
      expect(response).to redirect_to(account_types_path)
    end
  end
end
