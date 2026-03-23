require 'rails_helper'

RSpec.describe OverviewController, type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe 'GET #index' do
    it 'renders dashboard' do
      get overview_index_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Dashboard Financeiro')
    end

    context 'projected balance display' do
      let(:from_account) { create(:account, :asset, user: user) }
      let(:to_account) { create(:account, :expense_destination, user: user) }
      let(:category) { create(:category, :expense, user: user) }

      before do
        create(:transaction, :income, :confirmed, user: user,
               event_date: Date.today.beginning_of_month + 1.day,
               payment_date: Date.today.beginning_of_month + 1.day,
               amount: 5000)
        create(:transaction, :expense, :confirmed, user: user,
               event_date: Date.today.beginning_of_month + 2.days,
               payment_date: Date.today.beginning_of_month + 2.days,
               amount: 1000)
      end

      it 'displays projected balance section' do
        get overview_index_path
        expect(response.body).to include('Saldo Projetado')
      end

      it 'displays balance alert when projected balance is negative' do
        # Create large expense to make balance negative
        create(:transaction, :expense, :confirmed, user: user,
               event_date: Date.today.beginning_of_month + 3.days,
               payment_date: Date.today.beginning_of_month + 3.days,
               amount: 50000)

        get overview_index_path
        expect(response.body).to include('balance projetado')
      end
    end

    context 'category projections display' do
      let(:category) { create(:category, :expense, user: user) }

      before do
        # Create expense transactions across 3 months for averaging
        3.times do |i|
          month = Date.today.beginning_of_month - i.months
          create(:transaction, :expense, :confirmed, user: user,
                 category: category,
                 event_date: month + 5.days,
                 payment_date: month + 5.days,
                 amount: 300)
        end
      end

      it 'displays category projection section' do
        get overview_index_path
        expect(response.body).to include('Projeção por Categoria')
      end
    end
  end
end
