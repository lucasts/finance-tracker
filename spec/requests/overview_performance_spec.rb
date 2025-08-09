require 'rails_helper'

# Performance oriented spec to guard against excessive N+1 queries on dashboard.
RSpec.describe 'Overview performance', type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user
    # Seed multiple categories & transactions to trigger potential N+1 behavior
    6.times do |i|
      cat = create(:category, :expense, user: user, name: "Cat#{i}")
      5.times do
        create(:transaction, :expense, :confirmed, user: user, category: cat, event_date: Date.today.beginning_of_month + rand(0..10).days, payment_date: Date.today.beginning_of_month + rand(0..10).days, amount: rand(10..100))
      end
    end
    # Recurring commitments
    3.times do |i|
      create(:recurring_commitment, user: user, category: Category.where(user: user).expense.sample,
             from_account: create(:account, :asset, user: user), to_account: create(:account, :expense_destination, user: user),
             start_date: Date.today.beginning_of_month, default_amount: 50 + i, recurrence_frequency: 'weekly', status: :active, name: "RC#{i}")
    end
  end

  it 'limita número de queries ao carregar overview' do
    query_count = 0
    subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
      next if payload[:name] =~ /SCHEMA|TRANSACTION/ || payload[:cached]
      query_count += 1
    end

    get overview_index_path

    ActiveSupport::Notifications.unsubscribe(subscriber)

    # Intentional failing threshold for current (pre-optimization) implementation; adjust in refactor to pass
  expect(query_count).to be <= 30
  end
end
