class TransactionsController < ApplicationController
  def index
    month = params[:month] || Date.today.strftime('%Y-%m')
    @transactions = Transaction.in_competence_month(month).order(event_date: :desc)
  end

  def new
    @transaction = Transaction.new
  end

  def create
    @transaction = Transaction.new(transaction_params)
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
  
  def suggested_period_for(date:, from_account:)
    if from_account&.account_type&.role == "credit" && from_account&.due_day
      cutoff = Date.new(date.year, date.month, from_account.due_day)
      ref = (date <= cutoff) ? date : date + 1.month
      ref.strftime("%Y-%m")
    else
      date.strftime("%Y-%m")
    end
  end

  private

  def transaction_params
    params.require(:transaction).permit(
      :description, :amount, :transaction_type, :event_date, :payment_date,
      :from_account_id, :to_account_id, :category_id, :installment,
      :transaction_group_id, :status
    )
  end
end