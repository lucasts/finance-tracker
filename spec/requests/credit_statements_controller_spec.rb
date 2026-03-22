require "rails_helper"

RSpec.describe CreditStatementsController, type: :request do
  let(:user) { create(:user) }
  let(:account) { create(:account, :credit_card, user: user) }

  before { sign_in user }

  describe "authentication" do
    before { sign_out user }

    it "redirects unauthenticated users to sign in for index" do
      get credit_statements_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects unauthenticated users to sign in for show" do
      statement = create(:credit_statement, account: account)
      get credit_statement_path(statement)
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "GET /credit_statements" do
    it "returns http success" do
      get credit_statements_path
      expect(response).to have_http_status(:ok)
    end

    it "includes credit statements in the response body" do
      statement = create(:credit_statement, account: account)
      get credit_statements_path
      expect(response.body).to include(statement.month)
    end
  end

  describe "GET /credit_statements/:id" do
    let(:statement) { create(:credit_statement, account: account) }

    it "returns http success" do
      get credit_statement_path(statement)
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for a non-existent statement" do
      get credit_statement_path(id: 0)
      expect(response).to have_http_status(:not_found)
    end
  end
end
