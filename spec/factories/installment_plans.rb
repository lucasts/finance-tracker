FactoryBot.define do
  factory :installment_plan do
    name { "#{Faker::Commerce.product_name} Installment Plan" }
    installment_count { rand(2..12) }
    total_amount { Faker::Number.decimal(l_digits: 4, r_digits: 2) }
    starts_on { Date.current }
    recurrence_frequency { 'monthly' }
    status { 'active' }
    association :user
    association :category
    association :from_account, factory: :account
    association :to_account, factory: :account
  end
end
