class TransactionsController < ApplicationController
  include ActionView::Helpers::NumberHelper
  
  before_action :set_transaction, only: [:show, :edit, :update, :destroy]
  
  def index
    begin
      selected_month = Date.strptime(params[:month], "%Y-%m")
    rescue TypeError, ArgumentError
      selected_month = Date.today
    end

    @selected_month = selected_month
    @previous_month = selected_month - 1.month
    @next_month = selected_month + 1.month

    # Filter by current user
    @transactions = current_user_scope(Transaction).in_competence_month(selected_month).order(event_date: :desc)
    
    # Calculate initial balance (all transactions up to last day of previous month)
    last_day_previous_month = selected_month.beginning_of_month - 1.day
    previous_transactions = current_user_scope(Transaction)
      .where('event_date <= ?', last_day_previous_month)
      .where.not(transaction_type: 'transfer')
    
    @initial_balance = previous_transactions.sum do |tx|
      tx.transaction_type == 'income' ? tx.amount : -tx.amount
    end
    
    # Filter by installment plan if specified
    if params[:plan].present?
      @transactions = @transactions.where(installment_plan_id: params[:plan])
      @installment_plan = current_user_scope(InstallmentPlan).find_by(id: params[:plan])
    end
  end

  def show
    render partial: 'transaction_details', locals: { transaction: @transaction }
  end

  def new
    @transaction = current_user.transactions.build
    # Set intelligent defaults
    @transaction.event_date = Date.current
    @transaction.payment_date = Date.current
    @transaction.recurrence_type = 'single'
    # Status will be determined automatically based on dates
  end

  def create
    # Check if creating installment plan or recurring commitment
    if params[:create_installment_plan].present?
      create_installment_transaction
    elsif params[:create_recurring_commitment].present?
      create_recurring_transaction  
    else
      create_single_transaction
    end
  end

  def create_single_transaction
    service_params = transaction_params_for_service.to_h.symbolize_keys
    
    @transaction = CreateTransactionService.call(
      **service_params,
      user: current_user
    )

    if @transaction.persisted?
      # Handle credit card statement association if necessary
      if @transaction.credit_card_transaction?
        associate_with_credit_statement(@transaction)
        @transaction.save # Re-save to store statement association
      end
      redirect_to transactions_path, notice: 'Transaction was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    # For updates, we might need a different service or approach
    # For now, let's focus on creation. This part will need refactoring.
    if @transaction.update(transaction_params)
      if @transaction.credit_card_transaction?
        associate_with_credit_statement(@transaction)
        @transaction.save
      end
      redirect_to transactions_path, notice: t('messages.transaction.updated')
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @transaction.destroy
    redirect_to transactions_path, notice: t('messages.transaction.deleted')
  end
  
  private

  def set_transaction
    @transaction = current_user_scope(Transaction).find(params[:id])
  end

  def transaction_params_for_service
    # This method prepares the params for the CreateTransactionService
    base_params = params.require(:transaction).permit(
      :description, 
      :amount, 
      :event_date, 
      :payment_date, 
      :transaction_type,
      :category_id
    )
    
    entries_attrs = build_entries_from_form(params[:transaction])
    
    # Add category if provided
    category = Category.find_by(id: base_params[:category_id]) if base_params[:category_id].present?
    
    base_params.except(:category_id).merge(
      entries_attributes: entries_attrs,
      category: category
    )
  end

  def build_entries_from_form(params)
    # This method translates from/to account IDs from the form into debit/credit entries
    from_account_id = params[:from_account_id]
    to_account_id = params[:to_account_id]
    amount = FinancialConstants.safe_to_decimal(params[:amount])

    unless from_account_id && to_account_id && amount > 0
      # Add an error to the model instance if params are invalid
      @transaction ||= current_user.transactions.new
      @transaction.errors.add(:base, "Both from and to accounts must be selected, and amount must be positive.")
      return [] # Return empty to fail validation in the service
    end

    [
      { account_id: to_account_id, entry_type: 'debit', amount: amount },
      { account_id: from_account_id, entry_type: 'credit', amount: amount }
    ]
  end

  # Keep the original transaction_params for the update action for now
  def transaction_params
    params.require(:transaction).permit(
      :description, 
      :amount, 
      :event_date, 
      :payment_date, 
      :transaction_type,
      :category_id,
      :from_account_id, # Still needed for the form
      :to_account_id    # Still needed for the form
    )
  end

  def associate_with_credit_statement(transaction)
    # Use the service to find or create the statement
    statement = CreditStatementService.find_or_create_for_transaction(transaction)
    transaction.update_column(:credit_statement_id, statement.id) if statement
  end

  # New methods for the robust model
  def create_single_transaction
    # Build basic transaction attributes (excluding from_account_id/to_account_id)
    transaction_attrs = transaction_params_for_service.except(:from_account_id, :to_account_id)
    transaction_attrs[:user] = current_user
    transaction_attrs[:recurrence_type] = 'single'
    
    # Validate accounts belong to current user
    from_account_id = transaction_params[:from_account_id]
    to_account_id = transaction_params[:to_account_id]
    
    if from_account_id.present? && !current_user.accounts.exists?(id: from_account_id)
      @transaction = current_user.transactions.build(transaction_attrs)
      @transaction.errors.add(:base, "Conta de origem não encontrada ou não autorizada")
      render :new, status: :unprocessable_entity
      return
    end
    
    if to_account_id.present? && !current_user.accounts.exists?(id: to_account_id)
      @transaction = current_user.transactions.build(transaction_attrs)
      @transaction.errors.add(:base, "Conta de destino não encontrada ou não autorizada")
      render :new, status: :unprocessable_entity
      return
    end
    
    # Build entries based on transaction type
    entries = build_entries_for_transaction(transaction_attrs, from_account_id, to_account_id)
    
    # For transfers, ensure both accounts are provided and different
    if transaction_attrs[:transaction_type] == 'transfer'
      if !from_account_id.present? || !to_account_id.present?
        @transaction = current_user.transactions.build(transaction_attrs)
        @transaction.errors.add(:base, "Transferência deve ter conta de origem e destino")
        render :new, status: :unprocessable_entity
        return
      end
      
      if from_account_id == to_account_id
        @transaction = current_user.transactions.build(transaction_attrs)
        @transaction.errors.add(:base, "Conta de origem e destino não podem ser iguais")
        render :new, status: :unprocessable_entity
        return
      end
    end
    
    # Ensure we have valid entries
    if entries.empty?
      @transaction = current_user.transactions.build(transaction_attrs)
      @transaction.errors.add(:base, "Não foi possível criar as entradas de dupla entrada para esta transação")
      render :new, status: :unprocessable_entity
      return
    end
    
    # Use the CreateTransactionService
    @transaction = CreateTransactionService.call(
      description: transaction_attrs[:description],
      amount: transaction_attrs[:amount],
      event_date: transaction_attrs[:event_date],
      payment_date: transaction_attrs[:payment_date],
      transaction_type: transaction_attrs[:transaction_type],
      user: current_user,
      category: transaction_attrs[:category],
      entries_attributes: entries
    )
    
    if @transaction.persisted? && @transaction.errors.empty?
      redirect_to transactions_path, notice: t('messages.transaction.created')
    else
      render :new, status: :unprocessable_entity
    end
  end

  def create_recurring_transaction
    return create_single_transaction unless params[:create_recurring_commitment].present?

    ActiveRecord::Base.transaction do
      # Create the recurring commitment
      recurring_commitment = current_user.recurring_commitments.build(
        name: transaction_params[:description],
        category_id: transaction_params[:category_id],
        recurrence_frequency: params[:recurrence_frequency] || 'monthly',
        start_date: transaction_params[:event_date],
        status: 'active',
        from_account_id: transaction_params[:from_account_id],
        to_account_id: transaction_params[:to_account_id]
      )

      if recurring_commitment.save
        # Create the first transaction associated with the commitment
        @transaction = current_user.transactions.build(transaction_params)
        @transaction.recurrence_type = 'recurring'
        @transaction.recurring_commitment = recurring_commitment
        apply_intelligent_defaults(@transaction)
        if @transaction.credit_card_transaction?
          associate_with_credit_statement(@transaction)
        end
        if @transaction.save
          redirect_to transactions_path, notice: t('messages.transaction.recurring_created')
        else
          raise ActiveRecord::Rollback
        end
      else
        @transaction = Transaction.new(transaction_params)
        # Add the recurring commitment errors to the transaction object to display in the form
        recurring_commitment.errors.full_messages.each do |msg|
          @transaction.errors.add(:base, "Compromisso recorrente: #{msg}")
        end
        render :new, status: :unprocessable_entity
      end
    end
  rescue ActiveRecord::Rollback
    @transaction = Transaction.new(transaction_params) if @transaction.nil?
    @transaction.errors.add(:base, "Erro ao criar transação recorrente")
    render :new, status: :unprocessable_entity
  end

  def create_installment_transaction
    return create_single_transaction unless params[:create_installment_plan].present?

    installment_count = FinancialConstants.safe_to_integer(params[:installment_count])
    
    if installment_count < 2 || installment_count > 60
      @transaction = current_user.transactions.build(
        description: transaction_params[:description],
        amount: transaction_params[:amount],
        event_date: transaction_params[:event_date],
        payment_date: transaction_params[:payment_date],
        transaction_type: transaction_params[:transaction_type]
      )
      @transaction.errors.add(:base, "Número de parcelas deve estar entre 2 e 60")
      render :new, status: :unprocessable_entity
      return
    end

    ActiveRecord::Base.transaction do
      # Criar o plano de parcelamento
      category = Category.find_by(id: transaction_params[:category_id])
      installment_plan = current_user.installment_plans.build(
        name: "#{transaction_params[:description]} (#{installment_count}x)",
        category: category,
        installment_count: installment_count,
        total_amount: transaction_params[:amount],
        starts_on: transaction_params[:event_date],
        from_account_id: transaction_params[:from_account_id],
        to_account_id: transaction_params[:to_account_id]
      )

      if installment_plan.save
        # Create all installment transactions
        success = installment_plan.create_installment_transactions!({
          description_base: transaction_params[:description],
          transaction_type: transaction_params[:transaction_type],
          from_account_id: transaction_params[:from_account_id],
          to_account_id: transaction_params[:to_account_id]
        })

        if success
          # Apply special logic for credit cards on each transaction
          if Account.find(transaction_params[:from_account_id])&.account_type&.code == "CREDIT_CARD"
            account = Account.find(transaction_params[:from_account_id])
            
            # Pre-create all necessary credit statements for the installment period
            periods = CreditStatementService.calculate_periods_for_installment(
              installment_plan.starts_on, 
              installment_plan.installment_count, 
              installment_plan.recurrence_frequency
            )
            CreditStatementService.ensure_statements_for_periods(account, periods)
            
            # Associate each transaction with its respective statement
            installment_plan.transactions.each do |transaction|
              associate_with_credit_statement(transaction)
              transaction.save!
            end
          end

          redirect_to transactions_path, notice: t('messages.transaction.installments_created', 
                                                   count: installment_count)
        else
          raise ActiveRecord::Rollback
        end
      else
        @transaction = current_user.transactions.build(
          description: transaction_params[:description],
          amount: transaction_params[:amount],
          event_date: transaction_params[:event_date],
          payment_date: transaction_params[:payment_date],
          transaction_type: transaction_params[:transaction_type]
        )
        @transaction.errors.add(:base, "Erro ao criar plano de parcelamento: #{installment_plan.errors.full_messages.join(', ')}")
        render :new, status: :unprocessable_entity
      end
    end
  rescue ActiveRecord::Rollback
    @transaction = Transaction.new(transaction_params) if @transaction.nil?
    @transaction.errors.add(:base, "Erro ao criar parcelamento")
    render :new, status: :unprocessable_entity
  end

  private

  def build_entries_for_transaction(transaction_attrs, from_account_id, to_account_id)
    case transaction_attrs[:transaction_type]
    when 'income'
      # For income: money comes to an account (debit to receiving account)
      # The credit side is from a revenue account
      receiving_account_id = to_account_id || from_account_id
      revenue_account_id = from_account_id || find_or_create_category_account(transaction_attrs[:category]&.id, 'income')
      
      if receiving_account_id.present? && revenue_account_id.present?
        [
          { account_id: receiving_account_id, entry_type: 'debit', amount: transaction_attrs[:amount] },
          { account_id: revenue_account_id, entry_type: 'credit', amount: transaction_attrs[:amount] }
        ]
      else
        []
      end
    when 'expense'
      # For expense: money leaves an account (credit from paying account)
      # The debit side goes to an expense account
      paying_account_id = from_account_id
      expense_account_id = to_account_id || find_or_create_category_account(transaction_attrs[:category]&.id, 'expense')
      
      if paying_account_id.present? && expense_account_id.present?
        [
          { account_id: expense_account_id, entry_type: 'debit', amount: transaction_attrs[:amount] },
          { account_id: paying_account_id, entry_type: 'credit', amount: transaction_attrs[:amount] }
        ]
      else
        []
      end
    when 'transfer'
      # For transfer: straightforward debit to destination, credit from source
      if from_account_id.present? && to_account_id.present?
        [
          { account_id: to_account_id, entry_type: 'debit', amount: transaction_attrs[:amount] },
          { account_id: from_account_id, entry_type: 'credit', amount: transaction_attrs[:amount] }
        ]
      else
        []
      end
    else
      []
    end
  end

  def find_or_create_category_account(category_id, type)
    return nil unless category_id.present?
    
    category = Category.find_by(id: category_id, user: current_user)
    return nil unless category
    
    # Look for existing account matching the category name and type
    target_role = type == 'income' ? 'income' : 'expense'
    account_type = AccountType.find_by(role: target_role)
    return nil unless account_type
    
    # Find or create account for this category
    account = current_user.accounts.find_or_create_by(
      name: category.name,
      account_type: account_type
    )
    
    account.id
  end

end