class ApplicationController < ActionController::Base
  # Autenticação obrigatória em todos os controllers
  before_action :authenticate_user!

  protected

  # Método para filtrar recursos por usuário atual
  def current_user_scope(model_class)
    model_class.where(user: current_user)
  end
end
