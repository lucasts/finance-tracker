class TransactionsController < ApplicationController
  before_action :set_transaction, only: [:show, :edit, :update, :destroy]
  
  def index
    begin
      selected_month = Date.strptime(params[:month], "%Y-%m")
    rescue TypeError, ArgumentError
      selected_month = Date.today
    end

    @transactions = Transaction.in_competence_month(selected_month).order(event_date: :desc)
  end

  def show
    render partial: 'transaction_details', locals: { transaction: @transaction }
  end

  def new
    @transaction = Transaction.new
    # Set intelligent defaults
    @transaction.event_date = Date.current
    @transaction.payment_date = Date.current
    @transaction.status = 'confirmed'
    @transaction.recurrence_type = 'single'
  end

  def create
    @transaction = Transaction.new(transaction_params)
    
    # Apply intelligent defaults and validations
    apply_intelligent_defaults(@transaction)
    
    # Auto-associar com fatura se for cartão de crédito
    if @transaction.from_account&.account_type&.code == "CREDIT"
      associate_with_credit_statement(@transaction)
    end
    
    if @transaction.save
      redirect_to transactions_path, notice: 'Transação criada com sucesso!'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    # Reasociar com fatura se mudou conta ou data
    if @transaction.from_account&.account_type&.code == "CREDIT"
      associate_with_credit_statement(@transaction)
    end
    
    if @transaction.update(transaction_params)
      redirect_to transactions_path, notice: 'Transação atualizada com sucesso!'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @transaction.destroy
    redirect_to transactions_path, notice: 'Transação removida com sucesso!'
  end
  
  private

  def set_transaction
    @transaction = Transaction.find(params[:id])
  end

  def apply_intelligent_defaults(transaction)
    # Se não especificou payment_date, usa event_date
    transaction.payment_date ||= transaction.event_date
    
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
      :transaction_group_id, :status, :recurrence_type, :credit_statement_id
    )
  end
end