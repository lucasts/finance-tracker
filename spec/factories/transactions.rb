FactoryBot.define do
  factory :transaction do
    amount { Faker::Number.decimal(l_digits: 3, r_digits: 2) }
    event_date { Faker::Date.backward(days: 14) }
    payment_date { event_date }
    association :user
    description { Faker::Lorem.sentence }

    # Default to expense transaction
    transaction_type { 'expense' }

    # Use transient attributes to ensure user consistency and handle account parameters
    transient do
      user_for_association { user }
      # Default accounts that can be overridden
      from_account { association(:account, :asset, user: user_for_association) }
      to_account { association(:account, :expense_destination, user: user_for_association) }
    end

    category { association(:category, :expense, user: user_for_association) }

    # Create entries after the transaction is built
    after(:build) do |transaction, evaluator|
      # Skip if entries already exist (to avoid duplication)
      next if transaction.entries.any?

      # Skip if accounts are nil (for validation tests)
      next unless evaluator.from_account && evaluator.to_account

      # Build entries based on transaction type
      entries_data = case transaction.transaction_type
      when 'income'
        [
          { account_id: evaluator.from_account.id, entry_type: 'credit', amount: transaction.amount },
          { account_id: evaluator.to_account.id, entry_type: 'debit', amount: transaction.amount }
        ]
      when 'expense'
        [
          { account_id: evaluator.from_account.id, entry_type: 'credit', amount: transaction.amount },
          { account_id: evaluator.to_account.id, entry_type: 'debit', amount: transaction.amount }
        ]
      when 'transfer'
        [
          { account_id: evaluator.from_account.id, entry_type: 'credit', amount: transaction.amount },
          { account_id: evaluator.to_account.id, entry_type: 'debit', amount: transaction.amount }
        ]
      else
        # Default to expense pattern
        [
          { account_id: evaluator.from_account.id, entry_type: 'credit', amount: transaction.amount },
          { account_id: evaluator.to_account.id, entry_type: 'credit', amount: transaction.amount }
        ]
      end

      transaction.entries.build(entries_data)
    end

    trait :income do
      transaction_type { 'income' }
      transient do
        from_account { association(:account, :income_source, user: user_for_association) }
        to_account { association(:account, :asset, user: user_for_association) }
      end
      category { association(:category, :income, user: user_for_association) }
    end

    trait :expense do
      transaction_type { 'expense' }
      transient do
        from_account { association(:account, :asset, user: user_for_association) }
        to_account { association(:account, :expense_destination, user: user_for_association) }
      end
      category { association(:category, :expense, user: user_for_association) }
    end

    trait :transfer do
      transaction_type { 'transfer' }
      transient do
        from_account { association(:account, :asset, user: user_for_association) }
        to_account { association(:account, :asset, user: user_for_association) }
      end
      category { nil }  # Transfers don't have categories
    end

    trait :pending do
      payment_date { 1.week.from_now }
    end

    trait :confirmed do
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
