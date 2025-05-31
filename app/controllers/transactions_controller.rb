class TransactionsController < ApplicationController
  def index
    begin
      selected_month = Date.strptime(params[:month], "%Y-%m")
    rescue TypeError, ArgumentError
      selected_month = Date.today
    end

    @transactions = Transaction.in_competence_month(selected_month).order(event_date: :desc)
  end

  def show
    @transaction = Transaction.find(params[:id])
    render partial: 'transaction_details', locals: { transaction: @transaction }
  end

  def new
    @transaction = Transaction.new
  end

  def create
    @transaction = Transaction.new(transaction_params)
    
    # Auto-associar com fatura se for cartão de crédito
    if @transaction.from_account&.account_type&.code == "CREDIT"
      associate_with_credit_statement(@transaction)
    end
    
    if @transaction.save
      redirect_to transactions_path
    else
      render :new
    end
  end

  def edit
    @transaction = Transaction.find(params[:id])
  end

  def update
    @transaction = Transaction.find(params[:id])
    
    # Reasociar com fatura se mudou conta ou data
    if @transaction.from_account&.account_type&.code == "CREDIT"
      associate_with_credit_statement(@transaction)
    end
    
    if @transaction.update(transaction_params)
      redirect_to transactions_path
    else
      render :edit
    end
  end

  def destroy
    @transaction = Transaction.find(params[:id])
    @transaction.destroy
    redirect_to transactions_path
  end
  
  private

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
      :transaction_group_id, :status, :credit_statement_id
    )
  end
end