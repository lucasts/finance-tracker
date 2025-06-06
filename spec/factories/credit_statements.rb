FactoryBot.define do
  factory :credit_statement do
    month { Date.current.strftime('%Y-%m') }
    amount_due { Faker::Number.decimal(l_digits: 4, r_digits: 2) }
    amount_paid { 0.0 }
    status { 'open' }
    due_on { Date.current + 30.days }
    association :account
  end
end
