FactoryBot.define do
  factory :category do
    name { Faker::Commerce.department }
    association :user
  end
end
