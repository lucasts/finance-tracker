FactoryBot.define do
  factory :transaction do
    amount { Faker::Number.decimal(l_digits: 3, r_digits: 2) }
    event_date { Faker::Date.backward(days: 14) }
    payment_date { event_date }
    association :from_account, factory: :account
    association :to_account, factory: :account
    association :category
    association :user
    transaction_type { %w[income expense].sample }
    status { %w[pending confirmed cancelled].sample }
    description { Faker::Lorem.sentence }
    
    trait :income do
      transaction_type { 'income' }
    end
    
    trait :expense do
      transaction_type { 'expense' }
    end
    
    trait :pending do
      status { 'pending' }
      payment_date { 1.week.from_now }
    end
    
    trait :confirmed do
      status { 'confirmed' }
      payment_date { 1.week.ago }
    end
    
    trait :cancelled do
      status { 'cancelled' }
    end
    
    trait :recurring do
      recurrence_type { 'recurring' }
      association :recurring_commitment
    end
    
    trait :installment do
      recurrence_type { 'installment' }
      association :installment_plan
      installment_number { 1 }
    end
  end
end
