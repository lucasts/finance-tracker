FactoryBot.define do
  factory :recurring_commitment do
    name { "#{Faker::Commerce.department} Recurring Payment" }
    default_amount { Faker::Number.decimal(l_digits: 3, r_digits: 2) }
    recurrence_frequency { 'monthly' }
    start_date { Date.current }
    status { 'active' }
    association :user
    association :category
  end
end
