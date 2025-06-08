FactoryBot.define do
  factory :account do
    sequence(:name) { |n| "#{Faker::Bank.name} #{n}" } # Add sequence to ensure uniqueness
    association :user
    association :account_type

    trait :credit_card do
      association :account_type, :credit_card
    end
    
    trait :asset do
      association :account_type, :asset
    end
    
    trait :income_source do
      association :account_type, :income
    end
    
    trait :expense_destination do
      association :account_type, :expense
    end
  end
end
