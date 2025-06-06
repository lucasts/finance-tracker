require 'rails_helper'

RSpec.describe 'Month navigation and reports', type: :system do
  let!(:user) { create(:user) }

  before do
    driven_by(:selenium_firefox_headless)
    # Cria transações em meses diferentes
    login_as(user)
    category = create(:category, user: user, name: 'Salário')
    account = create(:account, user: user)
    create(:transaction, user: user, category: category, from_account: account, event_date: Date.current.beginning_of_month, transaction_type: 'income', amount: 1000)
    create(:transaction, user: user, category: category, from_account: account, event_date: 1.month.ago.beginning_of_month, transaction_type: 'income', amount: 2000)
  end

  it 'displays current month reports by default' do
    visit reports_path
    expect(page).to have_content('Junho de 2025')
    expect(page).to have_content('R$ 1.000,00').or have_content('R$ 1000,00')
  end

  it 'allows navigation to previous month and shows correct data' do
    visit reports_path
    find('a', text: '<').click
    expect(page).to have_content('Maio de 2025')
    expect(page).to have_content('R$ 2.000,00').or have_content('R$ 2000,00')
  end

  it 'allows navigation to next month and back' do
    visit reports_path(month: 1.month.ago.strftime('%Y-%m'))
    find('a', text: '>').click
    expect(page).to have_content('Junho de 2025')
  end
end
