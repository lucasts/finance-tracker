FactoryBot.define do
  factory :category do
    sequence(:name) { |n| "#{Faker::Commerce.department} #{n}" }
    category_type { 'expense' } # Default to expense
    association :user

    trait :income do
      category_type { 'income' }
    end

    trait :expense do
      category_type { 'expense' }
    end
  end
end
