FactoryBot.define do
  factory :import_session do
    association :user
    association :account
    source_type { 'csv' }
    original_filename { 'import_example.csv' }
    raw_file { File.read(Rails.root.join('spec/fixtures/files/import_example.csv')) }
  end
end
