FactoryBot.define do
  factory :transaction do
    amount { Faker::Number.decimal(l_digits: 3, r_digits: 2) }
    event_date { Faker::Date.backward(days: 14) }
    payment_date { event_date }
    association :user
    status { %w[pending confirmed cancelled].sample }
    description { Faker::Lorem.sentence }
    
    # Default to expense transaction
    transaction_type { 'expense' }
    
    # Use transient attributes to ensure user consistency
    transient do
      user_for_association { user }
    end
    
    from_account { association(:account, :asset, user: user_for_association) }
    to_account { association(:account, :expense_destination, user: user_for_association) }
    category { association(:category, :expense, user: user_for_association) }
    
    trait :income do
      transaction_type { 'income' }
      from_account { association(:account, :income_source, user: user_for_association) }
      to_account { association(:account, :asset, user: user_for_association) }
      category { association(:category, :income, user: user_for_association) }
    end
    
    trait :expense do
      transaction_type { 'expense' }
      from_account { association(:account, :asset, user: user_for_association) }
      to_account { association(:account, :expense_destination, user: user_for_association) }
      category { association(:category, :expense, user: user_for_association) }
    end
    
    trait :transfer do
      transaction_type { 'transfer' }
      from_account { association(:account, :asset, user: user_for_association) }
      to_account { association(:account, :asset, user: user_for_association) }
      category { nil }  # Transfers don't have categories
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
