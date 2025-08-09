require 'rails_helper'

RSpec.describe 'Overview chart caching', type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user
    # Seed some transactions across months
    6.times do |m|
      month_date = (Date.today - m.months).beginning_of_month + 5.days
      create(:transaction, :income, :confirmed, user: user, event_date: month_date, payment_date: month_date, amount: 100 + m)
      create(:transaction, :expense, :confirmed, user: user, event_date: month_date, payment_date: month_date, amount: 50 + m)
    end
  end

  it 'avoids rebuilding heavy chart data on subsequent request (memoizes result)' do
    Rails.cache.clear
    # Prime + one repeat (total two requests). Expect build only on first.
    events = 0
    subscriber = ActiveSupport::Notifications.subscribe('overview.build_chart_data') { events += 1 }
    get overview_index_path # build
    get overview_index_path # cached
    ActiveSupport::Notifications.unsubscribe(subscriber)
    expect(events).to eq(1)
  end
end
