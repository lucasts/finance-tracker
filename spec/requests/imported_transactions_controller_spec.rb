require "rails_helper"

RSpec.describe ImportedTransactionsController, type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:account) { create(:account, :asset, user: user) }
  let(:import_session) { create(:import_session, user: user, account: account) }
  let(:imported_transaction) { create(:imported_transaction, import_session: import_session) }

  before { sign_in user }

  describe "authentication" do
    before { sign_out user }

    it "redirects unauthenticated users when editing" do
      get edit_import_session_imported_transaction_path(import_session, imported_transaction)
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "authorization — user data isolation" do
    let(:other_account) { create(:account, :asset, user: other_user) }
    let(:other_session) { create(:import_session, user: other_user, account: other_account) }
    let(:other_imported_tx) { create(:imported_transaction, import_session: other_session) }

    it "denies access to imported transactions belonging to another user" do
      get edit_import_session_imported_transaction_path(other_session, other_imported_tx)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /import_sessions/:id/imported_transactions/:id/edit" do
    before { allow(ImportMatchingService).to receive(:call).and_return({}) }

    it "returns http success" do
      get edit_import_session_imported_transaction_path(import_session, imported_transaction)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /import_sessions/:id/imported_transactions/:id" do
    let(:category) { create(:category, :expense, user: user) }

    context "with 'ignore' action" do
      it "saves reconciliation decision and redirects to import session" do
        patch import_session_imported_transaction_path(import_session, imported_transaction),
              params: {
                reconciliation_action: "ignore",
                imported_transaction: {
                  description: "Coffee",
                  amount: "5.00",
                  event_date: Date.current.to_s,
                  payment_date: Date.current.to_s,
                  category_id: category.id,
                  transaction_type: "expense"
                }
              }
        expect(response).to redirect_to(import_session_path(import_session))
      end
    end

    context "with 'associate' action" do
      let(:existing_transaction) do
        from = create(:account, :asset, user: user)
        to = create(:account, :expense_destination, user: user)
        create(:transaction, :expense, user: user, category: category,
               from_account: from, to_account: to)
      end

      it "associates the imported transaction and redirects" do
        patch import_session_imported_transaction_path(import_session, imported_transaction),
              params: {
                reconciliation_action: "associate",
                matched_transaction_id: existing_transaction.id,
                imported_transaction: {
                  description: "Coffee",
                  amount: "5.00",
                  event_date: Date.current.to_s,
                  payment_date: Date.current.to_s,
                  category_id: category.id,
                  transaction_type: "expense"
                }
              }
        expect(response).to redirect_to(import_session_path(import_session))
      end
    end
  end
end
