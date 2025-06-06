FactoryBot.define do
  factory :account_type do
    name { Faker::Company.industry }
    code { Faker::Alphanumeric.alphanumeric(number: 4).upcase }
    role { %w[asset income expense].sample }

    trait :credit_card do
      code { 'CREDIT' }
      role { 'asset' }
      name { 'Cartão de Crédito' }
    end
  end
end
