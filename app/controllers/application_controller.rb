class ApplicationController < ActionController::Base
  
  # Mandatory authentication in all controllers
  before_action :authenticate_user!

  protected

  # Method to filter resources by current user
  def current_user_scope(model_class)
    model_class.where(user: current_user)
  end
end
