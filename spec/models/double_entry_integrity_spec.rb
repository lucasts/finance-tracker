require "rails_helper"

RSpec.describe "Double-entry bookkeeping integrity", type: :model do
  let(:user) { create(:user) }
  let(:asset_account) { create(:account, :asset, user: user) }
  let(:expense_account) { create(:account, :expense_destination, user: user) }
  let(:income_account) { create(:account, :income_source, user: user) }
  let(:category) { create(:category, :expense, user: user) }

  describe "Transaction#balance_of_entries validation" do
    it "rejects a transaction where debits do not equal credits" do
      tx = build(:transaction, :expense, user: user)
      # Manually add an unbalanced extra debit entry
      tx.entries.build(account: asset_account, entry_type: "debit", amount: 50)

      expect(tx).not_to be_valid
      expect(tx.errors[:base]).to include("The sum of debits and credits must be zero.")
    end

    it "rejects a transaction with only debit entries" do
      tx = Transaction.new(
        user: user,
        description: "Unbalanced debit-only",
        amount: 100,
        event_date: Date.current,
        payment_date: Date.current,
        transaction_type: "expense",
        category: category
      )
      tx.entries.build(account: asset_account, entry_type: "debit", amount: 100)

      expect(tx).not_to be_valid
      expect(tx.errors[:base]).to include("The sum of debits and credits must be zero.")
    end

    it "rejects a transaction with only credit entries" do
      tx = Transaction.new(
        user: user,
        description: "Unbalanced credit-only",
        amount: 100,
        event_date: Date.current,
        payment_date: Date.current,
        transaction_type: "expense",
        category: category
      )
      tx.entries.build(account: expense_account, entry_type: "credit", amount: 100)

      expect(tx).not_to be_valid
      expect(tx.errors[:base]).to include("The sum of debits and credits must be zero.")
    end

    it "accepts a transaction where sum(debits) == sum(credits)" do
      tx = create(:transaction, :expense, user: user, from_account: asset_account,
                  to_account: expense_account, category: category)

      debit_sum = tx.entries.select(&:debit?).sum(&:amount)
      credit_sum = tx.entries.select(&:credit?).sum(&:amount)

      expect(debit_sum).to eq(credit_sum)
    end
  end

  describe "Persisted transaction balance invariant" do
    it "all persisted transactions have balanced entries (sum(debits) == sum(credits))" do
      create(:transaction, :expense, user: user)
      create(:transaction, :income, user: user)
      create(:transaction, :transfer, user: user)

      Transaction.includes(:entries).find_each do |tx|
        debit_sum = tx.entries.select(&:debit?).sum(&:amount)
        credit_sum = tx.entries.select(&:credit?).sum(&:amount)
        expect(debit_sum).to eq(credit_sum),
          "Transaction ##{tx.id} (#{tx.description}) is unbalanced: debit=#{debit_sum} credit=#{credit_sum}"
      end
    end

    it "factory-built transactions are always balanced at creation" do
      expense = create(:transaction, :expense, user: user,
                       from_account: asset_account, to_account: expense_account,
                       category: category)

      debit_sum = expense.entries.select(&:debit?).sum(&:amount)
      credit_sum = expense.entries.select(&:credit?).sum(&:amount)
      expect(debit_sum).to eq(credit_sum)
      expect(debit_sum).to eq(expense.amount)
    end
  end

  describe "Transfer double-entry requirements" do
    it "transfer has exactly 2 entries on different accounts" do
      from = create(:account, :asset, user: user)
      to = create(:account, :asset, user: user)
      tx = create(:transaction, :transfer, user: user, from_account: from, to_account: to)

      expect(tx.entries.count).to eq(2)
      account_ids = tx.entries.map(&:account_id)
      expect(account_ids.uniq.count).to eq(2), "Transfer entries must use two distinct accounts"
    end

    it "rejects a transfer where from_account equals to_account" do
      account = create(:account, :asset, user: user)
      tx = Transaction.new(
        user: user,
        transaction_type: "transfer",
        description: "Same account transfer",
        amount: 100,
        event_date: Date.current,
        payment_date: Date.current,
        category: nil
      )
      tx.entries.build(account: account, entry_type: "debit", amount: 100)
      tx.entries.build(account: account, entry_type: "credit", amount: 100)

      expect(tx).not_to be_valid
      expect(tx.errors[:base]).to include("Conta de origem e destino não podem ser iguais em uma transferência")
    end

    it "transfer debit and credit amounts are equal" do
      from = create(:account, :asset, user: user)
      to = create(:account, :asset, user: user)
      tx = create(:transaction, :transfer, user: user, from_account: from, to_account: to, amount: 250)

      debit_entry = tx.entries.find(&:debit?)
      credit_entry = tx.entries.find(&:credit?)

      expect(debit_entry.amount).to eq(credit_entry.amount)
      expect(debit_entry.amount).to eq(tx.amount)
    end
  end

  describe "Entry count requirements" do
    it "an expense transaction has exactly one debit entry (source) and one credit entry (destination)" do
      tx = create(:transaction, :expense, user: user,
                  from_account: asset_account, to_account: expense_account,
                  category: category)

      expect(tx.entries.select(&:debit?).count).to eq(1)
      expect(tx.entries.select(&:credit?).count).to eq(1)
    end
  end
end
