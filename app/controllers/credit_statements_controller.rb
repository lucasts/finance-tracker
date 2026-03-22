class CreditStatementsController < ApplicationController
  def index
    @credit_statements = CreditStatement.includes(:account).order(month: :desc)
  end

  def show
    @credit_statement = CreditStatement.find(params[:id])
  end

  private
end
