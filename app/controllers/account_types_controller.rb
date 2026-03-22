class AccountTypesController < ApplicationController
  before_action :set_account_type, only: [ :edit, :update, :destroy ]

  def index
    @account_types = AccountType.order(:name)
  end

  def new
    @account_type = AccountType.new
  end

  def create
    @account_type = AccountType.new(account_type_params)
    if @account_type.save
      redirect_to account_types_path, notice: "Tipo de conta criado com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @account_type.update(account_type_params)
      redirect_to account_types_path, notice: "Tipo de conta atualizado com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @account_type.destroy
    redirect_to account_types_path, notice: "Tipo de conta removido."
  end

  private

  def set_account_type
    @account_type = AccountType.find(params[:id])
  end

  def account_type_params
    params.require(:account_type).permit(:code, :name, :role)
  end
end
