class RecurringCommitmentsController < ApplicationController
  before_action :set_recurring_commitment, only: [:show, :edit, :update, :destroy, :timeline, :toggle_active]
  
  def index
    @recurring_commitments = current_user_scope(RecurringCommitment).includes(:category, :transactions)
                                               .active
                                               .order(:name)
    
    @commitment_summaries = @recurring_commitments.map do |commitment|
      {
        commitment: commitment,
        next_occurrence: commitment.next_occurrence_date,
        total_spent: commitment.total_spent,
        average_amount: commitment.average_amount,
        transaction_count: commitment.transactions.count,
        last_transaction: commitment.transactions.order(:event_date).last
      }
    end
  end
  
  def show
    @recent_transactions = @recurring_commitment.transactions.order(date: :desc).limit(10)
    @next_transaction_date = calculate_next_transaction_date
    @total_generated = @recurring_commitment.transactions.sum(:amount)
  end
  
  def new
    @recurring_commitment = current_user.recurring_commitments.build
    @accounts = current_user_scope(Account).all
    @categories = current_user_scope(Category).all
  end
  
  def create
    @recurring_commitment = current_user.recurring_commitments.build(recurring_commitment_params)
    
    if @recurring_commitment.save
      redirect_to @recurring_commitment, notice: 'Compromisso recorrente criado com sucesso.'
    else
      @accounts = current_user_scope(Account).all
      @categories = current_user_scope(Category).all
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    @edit_strategies = %w[future_only all_transactions split_commitment]
    @accounts = current_user_scope(Account).all
    @categories = current_user_scope(Category).all
  end
  
  def update
    # Check if this is an advanced edit request
    if params[:recurring_commitment][:advanced_edit] == 'true'
      handle_advanced_edit
    else
      handle_standard_edit
    end
  end
  
  def toggle_active
    @recurring_commitment.update!(active: !@recurring_commitment.active)
    status = @recurring_commitment.active? ? 'ativado' : 'desativado'
    redirect_to recurring_commitments_path, notice: "Compromisso #{status} com sucesso."
  end
  
  def timeline
    months_back = params[:months_back]&.to_i || 6
    months_forward = params[:months_forward]&.to_i || 12
    
    start_date = Date.current - months_back.months
    end_date = Date.current + months_forward.months
    
    transactions = @recurring_commitment.transactions
                                       .where(date: start_date..end_date)
                                       .order(:date)
    
    timeline_data = transactions.map do |transaction|
      {
        id: transaction.id,
        date: transaction.date,
        amount: transaction.amount,
        description: transaction.description,
        type: transaction.transaction_type
      }
    end
    
    render json: {
      commitment: {
        id: @recurring_commitment.id,
        name: @recurring_commitment.name,
        frequency: @recurring_commitment.frequency
      },
      transactions: timeline_data,
      period: {
        start_date: start_date,
        end_date: end_date
      }
    }
  end
  
  def destroy
    @recurring_commitment.update(status: 'inactive')
    redirect_to recurring_commitments_path, notice: 'Recurring commitment deactivated.'
  end
  
  private
  
  def handle_advanced_edit
    edit_strategy = params[:recurring_commitment][:edit_strategy] || 'future_only'
    effective_date = params[:recurring_commitment][:effective_date]&.to_date || Date.current
    new_attributes = recurring_commitment_params.except(:edit_strategy, :effective_date, :advanced_edit)
    
    editor_service = RecurringCommitmentEditorService.new(
      recurring_commitment: @recurring_commitment,
      edit_strategy: edit_strategy,
      effective_date: effective_date,
      new_attributes: new_attributes
    )
    
    if editor_service.call
      success_message = case edit_strategy
                       when 'future_only'
                         'Compromisso atualizado. Mudanças aplicadas apenas às transações futuras.'
                       when 'all_transactions'
                         'Compromisso atualizado. Mudanças aplicadas a todas as transações.'
                       when 'split_commitment'
                         'Compromisso dividido com sucesso. Novo compromisso criado para as mudanças.'
                       end
      
      redirect_to @recurring_commitment, notice: success_message
    else
      @edit_strategies = %w[future_only all_transactions split_commitment]
      @accounts = current_user_scope(Account).all
      @categories = current_user_scope(Category).all
      flash.now[:alert] = editor_service.errors.full_messages.join(', ')
      render :show, status: :unprocessable_entity
    end
  end
  
  def handle_standard_edit
    if @recurring_commitment.update(recurring_commitment_params.except(:edit_strategy, :effective_date, :advanced_edit))
      redirect_to @recurring_commitment, notice: 'Compromisso recorrente atualizado com sucesso.'
    else
      @edit_strategies = %w[future_only all_transactions split_commitment]
      @accounts = current_user_scope(Account).all
      @categories = current_user_scope(Category).all
      render :edit, status: :unprocessable_entity
    end
  end
  
  def set_recurring_commitment
    @recurring_commitment = current_user_scope(RecurringCommitment).find(params[:id])
  end
  
  def recurring_commitment_params
    params.require(:recurring_commitment).permit(
      :name, :amount, :frequency, :start_date, :end_date, :transaction_type,
      :account_id, :category_id, :notes, :active, :edit_strategy, :effective_date, :advanced_edit
    )
  end
  
  private
  
  def calculate_next_transaction_date
    return nil unless @recurring_commitment.active?
    
    last_transaction = @recurring_commitment.transactions.order(:date).last
    return @recurring_commitment.start_date unless last_transaction
    
    case @recurring_commitment.frequency
    when 'daily'
      last_transaction.date + 1.day
    when 'weekly'
      last_transaction.date + 1.week
    when 'monthly'
      last_transaction.date + 1.month
    when 'yearly'
      last_transaction.date + 1.year
    end
  end
end
