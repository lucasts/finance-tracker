class RecurringCommitmentEditService
  EDIT_SCOPE_OPTIONS = %w[current_only from_current_forward all_periods].freeze
  
  attr_reader :commitment, :transaction, :params, :edit_scope
  
  def initialize(recurring_commitment, transaction, edit_params)
    @commitment = recurring_commitment
    @transaction = transaction
    @params = edit_params
    @edit_scope = edit_params[:edit_scope] || 'current_only'
  end
  
  def call
    case edit_scope
    when 'current_only'
      edit_current_transaction_only
    when 'from_current_forward'
      edit_from_current_forward
    when 'all_periods'
      edit_all_periods
    else
      { success: false, error: "Invalid edit scope: #{edit_scope}" }
    end
  end
  
  private
  
  def edit_current_transaction_only
    # Update only the current transaction, don't affect the commitment or future transactions
    ActiveRecord::Base.transaction do
      if transaction.update(transaction_params)
        # Mark this transaction as an exception to the recurring pattern
        transaction.update(recurrence_pattern: 'exception')
        
        { 
          success: true, 
          message: "Transaction updated as exception. Future recurring transactions remain unchanged.",
          affected_transactions: [transaction]
        }
      else
        { success: false, errors: transaction.errors.full_messages }
      end
    end
  end
  
  def edit_from_current_forward
    # Update the commitment's default values and all future transactions
    ActiveRecord::Base.transaction do
      future_transactions = commitment.transactions
                                     .where('event_date >= ?', transaction.event_date)
                                     .where.not(recurrence_pattern: 'exception')
      
      # Update the commitment with new default values
      commitment_updates = {}
      commitment_updates[:expected_amount] = params[:amount] if params[:amount].present?
      commitment_updates[:name] = params[:description] if params[:description].present?
      
      if commitment.update(commitment_updates)
        # Update current and future transactions
        updated_transactions = []
        future_transactions.find_each do |future_transaction|
          transaction_updates = transaction_params.except(:recurring_commitment_id)
          if future_transaction.update(transaction_updates)
            updated_transactions << future_transaction
          end
        end
        
        { 
          success: true, 
          message: "Updated commitment and #{updated_transactions.count} future transactions.",
          affected_transactions: updated_transactions
        }
      else
        { success: false, errors: commitment.errors.full_messages }
      end
    end
  end
  
  def edit_all_periods
    # Update the commitment and ALL related transactions (past and future)
    ActiveRecord::Base.transaction do
      all_transactions = commitment.transactions.where.not(recurrence_pattern: 'exception')
      
      # Update the commitment
      commitment_updates = {}
      commitment_updates[:expected_amount] = params[:amount] if params[:amount].present?
      commitment_updates[:name] = params[:description] if params[:description].present?
      
      if commitment.update(commitment_updates)
        # Update all non-exception transactions
        updated_transactions = []
        all_transactions.find_each do |related_transaction|
          transaction_updates = transaction_params.except(:recurring_commitment_id)
          if related_transaction.update(transaction_updates)
            updated_transactions << related_transaction
          end
        end
        
        { 
          success: true, 
          message: "Updated commitment and #{updated_transactions.count} transactions (past and future).",
          affected_transactions: updated_transactions
        }
      else
        { success: false, errors: commitment.errors.full_messages }
      end
    end
  end
  
  def transaction_params
    params.permit(:description, :amount, :transaction_type, :from_account_id, :to_account_id, :category_id, :notes)
  end
  
  # Generate timeline for UI visualization
  def self.generate_timeline(commitment, months_back: 6, months_forward: 12)
    timeline = []
    start_date = months_back.months.ago.beginning_of_month
    end_date = months_forward.months.from_now.end_of_month
    
    # Get existing transactions in the period
    existing_transactions = commitment.transactions
                                     .where(event_date: start_date..end_date)
                                     .order(:event_date)
    
    # Generate expected dates based on frequency
    current_date = commitment.start_date
    while current_date <= end_date
      if current_date >= start_date
        existing_transaction = existing_transactions.find { |t| t.event_date == current_date }
        
        timeline << {
          date: current_date,
          expected_amount: commitment.expected_amount,
          actual_transaction: existing_transaction,
          status: determine_timeline_status(current_date, existing_transaction),
          is_exception: existing_transaction&.recurrence_pattern == 'exception'
        }
      end
      
      current_date = commitment.next_occurrence_after(current_date)
      break if current_date.nil?
    end
    
    timeline
  end
  
  def self.determine_timeline_status(date, transaction)
    return 'future' if date > Date.current
    return 'completed' if transaction&.confirmed?
    return 'pending' if transaction&.pending?
    return 'missing' if transaction.nil?
    'unknown'
  end
end
