require 'rails_helper'

RSpec.describe 'CreditStatements', type: :system do
  let(:user) { create(:user) }
  let!(:account_type) { create(:account_type) }
  let!(:account) { create(:account, :credit_card) }
  let!(:statement) do
    create(:credit_statement, account: account, month: Date.current.strftime('%Y-%m'), amount_due: 500.0, amount_paid: 200.0, status: :open, due_on: Date.current + 5.days)
  end
  let!(:transaction) do
    create(:transaction, amount: 500.0, to_account: account, credit_statement: statement)
    statement.update!(amount_due: 500.0)
    statement.reload
  end

  before do
    driven_by(:rack_test)
    login_as(user)
  end

  it 'displays statements on dashboard' do
    visit overview_index_path
    expect(page).to have_content('Faturas do Cartão de Crédito')
    expect(page).to have_content(account.name)
    expect(page).to have_content('R$ 500,00')
  end
end
