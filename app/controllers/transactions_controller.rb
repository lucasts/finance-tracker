class TransactionsController < ApplicationController
  include ActionView::Helpers::NumberHelper
  
  before_action :set_transaction, only: [:show, :edit, :update, :destroy]
  
  def index
    begin
      selected_month = Date.strptime(params[:month], "%Y-%m")
    rescue TypeError, ArgumentError
      selected_month = Date.today
    end

    # Filter by current user
    @transactions = current_user_scope(Transaction).in_competence_month(selected_month).order(event_date: :desc)
    
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
    # Check recurrence type and process accordingly
    if params[:recurrence_type] == 'installment' || params[:create_installment_plan].present?
      create_installment_transaction
    elsif params[:recurrence_type] == 'recurring' || params[:create_recurring_commitment].present?
      create_recurring_transaction
    else
      create_single_transaction
    end
  end

  def edit; end

  def update
    # Reassociate with statement if account or date changed
    if @transaction.from_account&.account_type&.code == "CREDIT_CARD"
      associate_with_credit_statement(@transaction)
    end
    
    # Apply updated params
    @transaction.assign_attributes(transaction_params)
    
    # Reapply intelligent defaults after changes
    apply_intelligent_defaults(@transaction)
    
    if @transaction.save
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

  def apply_intelligent_defaults(transaction)
    # If payment_date not specified, use event_date
    transaction.payment_date ||= transaction.event_date
    
    # Automatically determine status based on business rules
    transaction.status = determine_automatic_status(transaction) if transaction.status.blank?
    
    # For credit cards, adjust payment_date automatically
    if transaction.from_account&.account_type&.code == "CREDIT_CARD" && transaction.from_account.due_day.present?
      # Payment date is on statement due date (next month)
      event_date = transaction.event_date
      due_date = Date.new(event_date.year, event_date.month, transaction.from_account.due_day)
      
      # If already past this month's closing, go to next
      if transaction.from_account.closing_day.present? && event_date.day > transaction.from_account.closing_day
        due_date = due_date.next_month
      else
        due_date = due_date.next_month
      end
      
      transaction.payment_date = due_date
    end
    
    # Auto-detect category based on description if not specified
    if transaction.category_id.blank? && transaction.description.present?
      suggested_category = suggest_category_from_description(transaction.description)
      transaction.category_id = suggested_category&.id if suggested_category
    end
  end

  def determine_automatic_status(transaction)
    current_date = Date.current
    payment_date = transaction.payment_date || transaction.event_date
    
    # Rules to determine status automatically:
    # 1. If payment date is in the future -> pending
    # 2. If today or past -> confirmed (assumed occurred)
    # 3. For installments: first installments confirmed, future pending
    
    if payment_date > current_date
      'pending'  # Future transaction
    else
      'confirmed'  # Current or past transaction (assumed occurred)
    end
  end

  def suggest_category_from_description(description)
    return nil if description.blank?
    
    desc = description.downcase
    
    # Keyword mapping for categories
    category_keywords = {
      'Supermercado' => ['mercado', 'supermercado', 'zaffari', 'carrefour', 'walmart', 'big'],
      'Farmácia' => ['farmácia', 'panvel', 'droga', 'medicamento', 'remédio'],
      'Combustível' => ['posto', 'gasolina', 'álcool', 'combustível', 'ipiranga', 'shell'],
      'Restaurante' => ['restaurante', 'ifood', 'uber eats', 'pizza', 'lanche', 'café'],
      'Saúde' => ['médico', 'dentista', 'hospital', 'consulta', 'exame'],
      'Educação' => ['escola', 'faculdade', 'curso', 'material escolar', 'mensalidade'],
      'Transporte' => ['uber', '99', 'ônibus', 'taxi', 'passagem', 'transporte'],
      'Lazer' => ['cinema', 'teatro', 'parque', 'viagem', 'netflix', 'spotify']
    }
    
    category_keywords.each do |category_name, keywords|
      if keywords.any? { |keyword| desc.include?(keyword) }
        return Category.find_by(name: category_name)
      end
    end
    
    nil
  end

  def associate_with_credit_statement(transaction)
    statement = CreditStatementService.find_or_create_for_transaction(transaction)
    transaction.credit_statement = statement if statement
  end

  def transaction_params
    permitted = params.require(:transaction).permit(
      :description, :amount, :transaction_type, :event_date, :payment_date,
      :from_account_id, :to_account_id, :category_id, :installment,
      :recurrence_type, :credit_statement_id,
      :recurrence_frequency, :installment_number,
      :status
    )
    # Normalize amount to decimal (ex: '123,77' => 123.77)
    if permitted[:amount].is_a?(String) && permitted[:amount].include?(',')
        permitted[:amount] = permitted[:amount].gsub('.', '').gsub(',', '.')
    end
    permitted[:amount] = permitted[:amount].to_d if permitted[:amount].present?
    permitted
  end

  # New methods for the robust model
  def create_single_transaction
    @transaction = current_user.transactions.build(transaction_params)
    @transaction.recurrence_type = 'single'
    
    # Validate that accounts belong to current user
    unless validate_account_ownership(@transaction)
      @transaction.errors.add(:base, "Conta não encontrada ou não autorizada")
      render :new, status: :unprocessable_entity
      return
    end
    
    # Apply intelligent defaults and validations
    apply_intelligent_defaults(@transaction)
    
    # Auto-associate with statement if it's a credit card
    if @transaction.from_account&.account_type&.code == "CREDIT_CARD"
      associate_with_credit_statement(@transaction)
    end
    
    if @transaction.save
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
        if @transaction.from_account&.account_type&.code == "CREDIT_CARD"
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

    installments_count = params[:installments_count].to_i
    
    if installments_count < 2 || installments_count > 60
      @transaction = Transaction.new(transaction_params)
      @transaction.errors.add(:base, "Número de parcelas deve estar entre 2 e 60")
      render :new, status: :unprocessable_entity
      return
    end

    ActiveRecord::Base.transaction do
      # Criar o plano de parcelamento
      installment_plan = current_user.installment_plans.build(
        name: "#{transaction_params[:description]} (#{installments_count}x)",
        category_id: transaction_params[:category_id],
        installment_count: installments_count,
        total_amount: transaction_params[:amount],
        starts_on: transaction_params[:event_date]
      )

      if installment_plan.save
        # Create all installment transactions
        success = installment_plan.create_installment_transactions!(
          description_base: transaction_params[:description],
          transaction_type: transaction_params[:transaction_type],
          from_account_id: transaction_params[:from_account_id],
          to_account_id: transaction_params[:to_account_id]
        )

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
                                                   count: installments_count)
        else
          raise ActiveRecord::Rollback
        end
      else
        @transaction = Transaction.new(transaction_params)
        @transaction.errors.add(:base, "Erro ao criar plano de parcelamento: #{installment_plan.errors.full_messages.join(', ')}")
        render :new, status: :unprocessable_entity
      end
    end
  rescue ActiveRecord::Rollback
    @transaction = Transaction.new(transaction_params) if @transaction.nil?
    @transaction.errors.add(:base, "Erro ao criar parcelamento")
    render :new, status: :unprocessable_entity
  end

  def validate_account_ownership(transaction)
    if transaction.from_account_id.present?
      from_account = current_user_scope(Account).find_by(id: transaction.from_account_id)
      return false unless from_account
    end
    
    if transaction.to_account_id.present?
      to_account = current_user_scope(Account).find_by(id: transaction.to_account_id)
      return false unless to_account
    end
    
    true
  end

end