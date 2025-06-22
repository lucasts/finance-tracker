# Service for advanced editing of recurring commitments
# Allows modifying existing commitments with different strategies
class RecurringCommitmentEditorService
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :recurring_commitment
  attribute :edit_strategy, :string, default: 'future_only'
  attribute :effective_date, :date, default: -> { Date.current }
  attribute :new_attributes, default: -> { {} }

  validates :recurring_commitment, presence: true
  validates :edit_strategy, inclusion: { in: %w[future_only all_transactions split_commitment] }
  validates :effective_date, presence: true
  validates :new_attributes, presence: true

  # Editing strategies:
  # - future_only: Apply changes only to future transactions
  # - all_transactions: Apply changes to all transactions (past and future)
  # - split_commitment: Create a new commitment from the effective date
  
  def call
    return false unless valid?
    
    ActiveRecord::Base.transaction do
      case edit_strategy
      when 'future_only'
        edit_future_transactions_only
      when 'all_transactions'
        edit_all_transactions
      when 'split_commitment'
        split_commitment
      end
    end
    
    true
  rescue StandardError => e
    errors.add(:base, "Erro ao editar compromisso: #{e.message}")
    false
  end

  private

  def edit_future_transactions_only
    # Update the commitment with new attributes
    recurring_commitment.update!(filtered_new_attributes)
    
    # Update future transactions (including effective date)
    future_transactions = recurring_commitment.transactions.where('date >= ?', effective_date)
    
    future_transactions.find_each do |transaction|
      update_transaction_attributes(transaction)
    end
    
    Rails.logger.info "Updated #{future_transactions.count} future transactions for commitment #{recurring_commitment.id}"
  end

  def edit_all_transactions
    # Update the commitment with new attributes
    recurring_commitment.update!(filtered_new_attributes)
    
    # Update all commitment transactions
    all_transactions = recurring_commitment.transactions
    
    all_transactions.find_each do |transaction|
      update_transaction_attributes(transaction)
    end
    
    Rails.logger.info "Updated #{all_transactions.count} transactions for commitment #{recurring_commitment.id}"
  end

  def split_commitment
    # Deactivate the original commitment at the effective date
    original_end_date = effective_date - 1.day
    recurring_commitment.update!(end_date: original_end_date)
    
    # Create new commitment with the new attributes
    new_commitment_attributes = recurring_commitment.attributes.except('id', 'created_at', 'updated_at')
                                                    .merge(filtered_new_attributes)
                                                    .merge(start_date: effective_date, end_date: nil)
    
    new_commitment = RecurringCommitment.create!(new_commitment_attributes)
    
    # Move future transactions to the new commitment
    future_transactions = recurring_commitment.transactions.where('date >= ?', effective_date)
    
    future_transactions.find_each do |transaction|
      transaction.update!(recurring_commitment: new_commitment)
      update_transaction_attributes(transaction)
    end
    
    Rails.logger.info "Split commitment #{recurring_commitment.id}. Created new commitment #{new_commitment.id} with #{future_transactions.count} transactions"
    
    @new_commitment = new_commitment
  end

  def update_transaction_attributes(transaction)
    # Update transaction attributes based on new commitment attributes
    transaction_updates = {}
    
    transaction_updates[:description] = new_attributes[:name] if new_attributes[:name].present?
    transaction_updates[:amount] = new_attributes[:amount] if new_attributes[:amount].present?
    transaction_updates[:transaction_type] = new_attributes[:transaction_type] if new_attributes[:transaction_type].present?
    transaction_updates[:account_id] = new_attributes[:account_id] if new_attributes[:account_id].present?
    transaction_updates[:category_id] = new_attributes[:category_id] if new_attributes[:category_id].present?
    
    transaction.update!(transaction_updates) if transaction_updates.any?
  end

  def filtered_new_attributes
    # Remove attributes that should not be applied directly to the model
    new_attributes.except('edit_strategy', 'effective_date')
  end

  # Getter for the new commitment created (when strategy is split_commitment)
  def new_commitment
    @new_commitment
  end

  # Convenience methods for using the service
  class << self
    def edit_future_only(commitment, new_attributes, effective_date = Date.current)
      new(
        recurring_commitment: commitment,
        edit_strategy: 'future_only',
        effective_date: effective_date,
        new_attributes: new_attributes
      ).call
    end

    def edit_all_transactions(commitment, new_attributes)
      new(
        recurring_commitment: commitment,
        edit_strategy: 'all_transactions',
        effective_date: Date.current,
        new_attributes: new_attributes
      ).call
    end

    def split_commitment(commitment, new_attributes, effective_date)
      service = new(
        recurring_commitment: commitment,
        edit_strategy: 'split_commitment',
        effective_date: effective_date,
        new_attributes: new_attributes
      )
      
      result = service.call
      [result, service.new_commitment]
    end
  end
end
