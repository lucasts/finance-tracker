class TransactionsController < ApplicationController
  include ActionView::Helpers::NumberHelper
  
  before_action :set_transaction, only: [:show, :edit, :update, :destroy]
  
  def index
    begin
      selected_month = Date.strptime(params[:month], "%Y-%m")
    rescue TypeError, ArgumentError
      selected_month = Date.today
    end

    # Filtrar por usuário atual
    @transactions = current_user_scope(Transaction).in_competence_month(selected_month).order(event_date: :desc)
    
    # Filtrar por plano de parcelamento se especificado
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
    # Status será determinado automaticamente baseado nas datas
  end

  def create
    # Verifica o tipo de recorrência e processa adequadamente
    case params[:recurrence_type]
    when 'recurring'
      create_recurring_transaction
    when 'installment'
      create_installment_transaction
    else
      create_single_transaction
    end
  end

  def edit; end

  def update
    # Reasociar com fatura se mudou conta ou data
    if @transaction.from_account&.account_type&.code == "CREDIT"
      associate_with_credit_statement(@transaction)
    end
    
    # Apply updated params
    @transaction.assign_attributes(transaction_params)
    
    # Reaplica defaults inteligentes após mudanças
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
    # Se não especificou payment_date, usa event_date
    transaction.payment_date ||= transaction.event_date
    
    # Determina status automaticamente baseado nas regras de negócio
    transaction.status = determine_automatic_status(transaction) if transaction.status.blank?
    
    # Para cartões de crédito, ajusta payment_date automaticamente
    if transaction.from_account&.account_type&.code == "CREDIT" && transaction.from_account.due_day.present?
      # Payment date é no vencimento da fatura (próximo mês)
      event_date = transaction.event_date
      due_date = Date.new(event_date.year, event_date.month, transaction.from_account.due_day)
      
      # Se já passou do fechamento deste mês, vai para o próximo
      if transaction.from_account.closing_day.present? && event_date.day > transaction.from_account.closing_day
        due_date = due_date.next_month
      else
        due_date = due_date.next_month
      end
      
      transaction.payment_date = due_date
    end
    
    # Auto-detecta categoria baseada na descrição se não foi especificada
    if transaction.category_id.blank? && transaction.description.present?
      suggested_category = suggest_category_from_description(transaction.description)
      transaction.category_id = suggested_category&.id if suggested_category
    end
  end

  def determine_automatic_status(transaction)
    current_date = Date.current
    payment_date = transaction.payment_date || transaction.event_date
    
    # Regras para determinar status automaticamente:
    # 1. Se a data de pagamento for futura -> pending
    # 2. Se for hoje ou passado -> confirmed (assumindo que aconteceu)
    # 3. Para parcelamentos: primeiras parcelas confirmed, futuras pending
    
    if payment_date > current_date
      'pending'  # Transação futura
    else
      'confirmed'  # Transação atual ou passada (assumindo que aconteceu)
    end
  end

  def suggest_category_from_description(description)
    return nil if description.blank?
    
    desc = description.downcase
    
    # Mapeamento de palavras-chave para categorias
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

  def suggested_period_for(date:, from_account:)
    if from_account&.account_type&.code == "CREDIT" && from_account&.closing_day
      cutoff = Date.new(date.year, date.month, from_account.closing_day)
      ref = (date <= cutoff) ? date : date + 1.month
      ref.strftime("%Y-%m")
    else
      date.strftime("%Y-%m")
    end
  end

  def associate_with_credit_statement(transaction)
    return unless transaction.from_account&.account_type&.code == "CREDIT"
    
    period = suggested_period_for(date: transaction.event_date, from_account: transaction.from_account)
    statement = CreditStatement.find_by(account: transaction.from_account, month: period)
    
    if statement
      transaction.credit_statement = statement
    end
  end

  def transaction_params
    params.require(:transaction).permit(
      :description, :amount, :transaction_type, :event_date, :payment_date,
      :from_account_id, :to_account_id, :category_id, :installment,
      :recurrence_type, :credit_statement_id,
      :recurrence_frequency, :installment_number
      # status removido - será controlado automaticamente
    )
  end

  # Novos métodos para o modelo robusto
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
    
    # Auto-associar com fatura se for cartão de crédito
    if @transaction.from_account&.account_type&.code == "CREDIT"
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
      # Criar o compromisso recorrente
      recurring_commitment = current_user.recurring_commitments.build(
        name: transaction_params[:description],
        category_id: transaction_params[:category_id],
        frequency: params[:recurrence_frequency] || 'monthly',
        amount_type: params[:recurring_amount_type] || 'fixed',
        expected_amount: (params[:recurring_amount_type] == 'fixed' ? transaction_params[:amount] : nil),
        start_date: transaction_params[:event_date],
        status: 'active'
      )

      if recurring_commitment.save
        # Criar a primeira transação associada ao compromisso
        @transaction = current_user.transactions.build(transaction_params)
        @transaction.recurrence_type = 'recurring'
        @transaction.recurring_commitment = recurring_commitment
        
        apply_intelligent_defaults(@transaction)
        
        if @transaction.from_account&.account_type&.code == "CREDIT"
          associate_with_credit_statement(@transaction)
        end

        if @transaction.save
          redirect_to transactions_path, notice: t('messages.transaction.recurring_created')
        else
          raise ActiveRecord::Rollback
        end
      else
        @transaction = Transaction.new(transaction_params)
        @transaction.errors.add(:base, "Erro ao criar compromisso recorrente: #{recurring_commitment.errors.full_messages.join(', ')}")
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
        # Criar todas as transações do parcelamento
        success = installment_plan.create_installment_transactions!(
          description_base: transaction_params[:description],
          transaction_type: transaction_params[:transaction_type],
          from_account_id: transaction_params[:from_account_id],
          to_account_id: transaction_params[:to_account_id]
        )

        if success
          # Aplicar lógica especial para cartões de crédito em cada transação
          if Account.find(transaction_params[:from_account_id])&.account_type&.code == "CREDIT"
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