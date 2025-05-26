class TransactionsController < ApplicationController
  def index
    @transactions = Transaction.includes(:category, :from_account, :to_account).all
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

  private

  def transaction_params
    params.require(:transaction).permit(:description, :amount, :type, :date, :period,
      :from_account_id, :to_account_id, :category_id, :installment, :status, :transaction_group_id)
  end
end