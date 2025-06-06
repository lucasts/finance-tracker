FactoryBot.define do
  factory :account do
    name { Faker::Bank.name } # Usa um método que existe no locale en
    association :user
    association :account_type

    trait :credit_card do
      association :account_type, :credit_card
    end
  end
end
