FactoryBot.define do
  factory :account_type do
    # Use existing account types from seeds instead of creating random ones
    initialize_with { AccountType.find_by(role: 'asset') || AccountType.create!(name: 'Test Asset', code: 'TEST', role: 'asset') }

    trait :credit_card do
      initialize_with { AccountType.find_by(code: 'CREDIT') || AccountType.create!(code: 'CREDIT', role: 'asset', name: 'Cartão de Crédito') }
    end
    
    trait :asset do
      initialize_with { AccountType.find_by(code: 'BANK') || AccountType.create!(code: 'BANK', role: 'asset', name: 'Conta Corrente') }
    end
    
    trait :income do
      initialize_with { AccountType.find_by(code: 'REVENUE') || AccountType.create!(code: 'REVENUE', role: 'income', name: 'Receita') }
    end
    
    trait :expense do
      initialize_with { AccountType.find_by(code: 'EXPENSE') || AccountType.create!(code: 'EXPENSE', role: 'expense', name: 'Despesa') }
    end
  end
end
