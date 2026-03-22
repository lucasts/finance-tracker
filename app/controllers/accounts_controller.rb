class AccountsController < ApplicationController
  before_action :set_account, only: [ :edit, :update, :destroy ]

  def index
    @accounts = current_user_scope(Account).includes(:account_type).order(:name)
  end

  def new
    @account = current_user.accounts.build
  end

  def create
    @account = current_user.accounts.build(account_params)
    if @account.save
      redirect_to accounts_path, notice: "Conta criada com sucesso."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @account.update(account_params)
      redirect_to accounts_path, notice: "Conta atualizada com sucesso."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @account.destroy
      redirect_to accounts_path, notice: "Conta removida com sucesso."
    else
      redirect_to accounts_path, alert: "A conta não pode ser removida pois possui transações associadas."
    end
  end

  private

  def set_account
    @account = current_user_scope(Account).find(params[:id])
  end

  def account_params
    params.require(:account).permit(:name, :account_type_id)
  end
end
