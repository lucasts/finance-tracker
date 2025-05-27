class TransactionGroupsController < ApplicationController
  before_action :set_transaction_group, only: [:edit, :update, :destroy]

  def index
    @transaction_groups = TransactionGroup.order(:name)
  end

  def new
    @transaction_group = TransactionGroup.new
  end

  def create
    @transaction_group = TransactionGroup.new(transaction_group_params)
    if @transaction_group.save
      redirect_to transaction_groups_path, notice: "Grupo de transação criado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @transaction_group.update(transaction_group_params)
      redirect_to transaction_groups_path, notice: "Grupo de transação atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @transaction_group.destroy
    redirect_to transaction_groups_path, notice: "Grupo de transação removido."
  end

  def show
    @group = TransactionGroup.find(params[:id])
    @transactions = @group.transactions.sort_by { |t| -t.installment.to_i }

    @paid = @transactions.select { |t| t.status == "confirmed" }
    @unpaid = @transactions.reject { |t| t.status == "confirmed" }

    @total_paid = @paid.sum(&:amount)
    @total_due = @unpaid.sum(&:amount)
    @total_value = @transactions.sum(&:amount)
  end

  private

  def set_transaction_group
    @transaction_group = TransactionGroup.find(params[:id])
  end

  def transaction_group_params
    params.require(:transaction_group).permit(:code, :name, :role)
  end
end
