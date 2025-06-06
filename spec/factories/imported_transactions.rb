FactoryBot.define do
  factory :imported_transaction do
    association :import_session
    line_number { 1 }
    raw_data { '{}' }
    amount { 100.0 }
    status { 'pending' }
  end
end
