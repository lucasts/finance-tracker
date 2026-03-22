# Unified service for recurring commitment editing
# Consolidates RecurringCommitmentEditService and RecurringCommitmentEditorService
class RecurringCommitmentEditorUnifiedService
  include ActiveModel::Model
  include ActiveModel::Attributes

  # Strategy options for editing
  EDIT_STRATEGIES = %w[current_only from_current_forward all_periods split_commitment].freeze

  attribute :recurring_commitment
  attribute :transaction, optional: true
  attribute :edit_strategy, :string, default: "current_only"
  attribute :effective_date, :date, default: -> { Date.current }
  attribute :new_attributes, default: -> { {} }

  validates :recurring_commitment, presence: true
  validates :edit_strategy, inclusion: { in: EDIT_STRATEGIES }
  validates :effective_date, presence: true
  validates :new_attributes, presence: true

  def call
    return { success: false, errors: errors.full_messages } unless valid?

    case edit_strategy
    when "current_only"
      edit_current_transaction_only
    when "from_current_forward"
      edit_from_current_forward
    when "all_periods"
      edit_all_periods
    when "split_commitment"
      split_commitment_from_date
    else
      { success: false, errors: [ "Invalid edit strategy: #{edit_strategy}" ] }
    end
  rescue ActiveRecord::RecordInvalid => e
    { success: false, errors: [ e.message ] }
  rescue StandardError => e
    { success: false, errors: [ "Unexpected error: #{e.message}" ] }
  end

  private

  def edit_current_transaction_only
    # Only edit the specific transaction without affecting the commitment pattern
    return { success: false, errors: [ "Transaction required for current_only strategy" ] } unless transaction

    ActiveRecord::Base.transaction do
      transaction_updates = extract_transaction_attributes

      if transaction.update(transaction_updates)
        # Update accounts if provided
        update_transaction_accounts(transaction, new_attributes[:from_account_id], new_attributes[:to_account_id])
        { success: true, updated_transactions: [ transaction ], updated_commitment: nil }
      else
        { success: false, errors: transaction.errors.full_messages }
      end
    end
  end

  def edit_from_current_forward
    # Update the commitment and all future transactions
    ActiveRecord::Base.transaction do
      # Update commitment with new defaults
      commitment_updates = extract_commitment_attributes
      recurring_commitment.update!(commitment_updates)

      # Update all future transactions (including current if provided)
      start_date = transaction&.event_date || effective_date
      future_transactions = recurring_commitment.transactions
                                               .where("event_date >= ?", start_date)

      updated_transactions = []
      transaction_updates = extract_transaction_attributes

      future_transactions.find_each do |tx|
        if tx.update(transaction_updates)
          # Update accounts if provided
          update_transaction_accounts(tx, new_attributes[:from_account_id], new_attributes[:to_account_id])
          updated_transactions << tx
        else
          raise ActiveRecord::RecordInvalid.new(tx)
        end
      end

      {
        success: true,
        updated_transactions: updated_transactions,
        updated_commitment: recurring_commitment
      }
    end
  end

  def edit_all_periods
    # Update the commitment and ALL transactions (past and future)
    ActiveRecord::Base.transaction do
      # Update commitment
      commitment_updates = extract_commitment_attributes
      recurring_commitment.update!(commitment_updates)

      # Update ALL transactions
      all_transactions = recurring_commitment.transactions
      updated_transactions = []
      transaction_updates = extract_transaction_attributes

      all_transactions.find_each do |tx|
        if tx.update(transaction_updates)
          # Update accounts if provided
          update_transaction_accounts(tx, new_attributes[:from_account_id], new_attributes[:to_account_id])
          updated_transactions << tx
        else
          raise ActiveRecord::RecordInvalid.new(tx)
        end
      end

      {
        success: true,
        updated_transactions: updated_transactions,
        updated_commitment: recurring_commitment
      }
    end
  end

  def split_commitment_from_date
    # Create a new commitment from the effective date with new attributes
    ActiveRecord::Base.transaction do
      # End the current commitment at the effective date
      original_end_date = recurring_commitment.end_date
      recurring_commitment.update!(end_date: effective_date - 1.day)

      # Create new commitment with updated attributes
      new_commitment_attrs = recurring_commitment.attributes
                                                .except("id", "created_at", "updated_at")
                                                .merge(extract_commitment_attributes)
                                                .merge(
                                                  start_date: effective_date,
                                                  end_date: original_end_date
                                                )

      new_commitment = RecurringCommitment.create!(new_commitment_attrs)

      # Update future transactions to belong to new commitment
      future_transactions = recurring_commitment.transactions
                                               .where("event_date >= ?", effective_date)

      transaction_updates = extract_transaction_attributes
                             .merge(recurring_commitment: new_commitment)

      updated_transactions = []
      future_transactions.find_each do |tx|
        if tx.update(transaction_updates)
          # Update accounts if provided
          update_transaction_accounts(tx, new_attributes[:from_account_id], new_attributes[:to_account_id])
          updated_transactions << tx
        else
          raise ActiveRecord::RecordInvalid.new(tx)
        end
      end

      {
        success: true,
        updated_transactions: updated_transactions,
        updated_commitment: recurring_commitment,
        new_commitment: new_commitment
      }
    end
  end

  def extract_commitment_attributes
    # Extract attributes that should be applied to the commitment
    commitment_attrs = {}

    commitment_attrs[:name] = new_attributes[:name] if new_attributes[:name].present?
    commitment_attrs[:default_amount] = new_attributes[:amount] if new_attributes[:amount].present?
    commitment_attrs[:category_id] = new_attributes[:category_id] if new_attributes[:category_id].present?
    commitment_attrs[:from_account_id] = new_attributes[:from_account_id] if new_attributes[:from_account_id].present?
    commitment_attrs[:to_account_id] = new_attributes[:to_account_id] if new_attributes[:to_account_id].present?
    commitment_attrs[:notes] = new_attributes[:notes] if new_attributes.key?(:notes)

    commitment_attrs
  end

  def extract_transaction_attributes
    # Extract attributes that should be applied to transactions
    transaction_attrs = {}

    transaction_attrs[:description] = new_attributes[:name] if new_attributes[:name].present?
    transaction_attrs[:amount] = new_attributes[:amount] if new_attributes[:amount].present?
    transaction_attrs[:category_id] = new_attributes[:category_id] if new_attributes[:category_id].present?

    # Note: from_account_id and to_account_id are no longer direct transaction attributes
    # They are handled through entries. For updating existing transactions, we need to
    # update the associated entries instead.

    transaction_attrs
  end

  def update_transaction_accounts(transaction, from_account_id, to_account_id)
    # Helper method to update transaction accounts via entries
    return unless from_account_id.present? || to_account_id.present?

    # Clear existing entries
    transaction.entries.destroy_all

    # Create new entries based on transaction type
    if from_account_id && to_account_id
      case transaction.transaction_type
      when "income"
        # For income: revenue account (from) credits, user account (to) debits
        transaction.entries.create!([
          { account_id: to_account_id, entry_type: "debit", amount: transaction.amount },
          { account_id: from_account_id, entry_type: "credit", amount: transaction.amount }
        ])
      when "expense"
        # For expense: user account (from) credits, expense account (to) debits
        transaction.entries.create!([
          { account_id: to_account_id, entry_type: "debit", amount: transaction.amount },
          { account_id: from_account_id, entry_type: "credit", amount: transaction.amount }
        ])
      when "transfer"
        # For transfer: from account credits, to account debits
        transaction.entries.create!([
          { account_id: to_account_id, entry_type: "debit", amount: transaction.amount },
          { account_id: from_account_id, entry_type: "credit", amount: transaction.amount }
        ])
      end
    end
  end
end
