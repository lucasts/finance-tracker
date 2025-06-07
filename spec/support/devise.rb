# Devise test helpers for Rails 8
RSpec.configure do |config|
  config.include Devise::Test::ControllerHelpers, type: :controller
  
  # Custom authentication helper for request specs that works with Rails 8
  config.before(:each, type: :request) do
    def sign_in(user, options = {})
      # Use the session approach that works reliably in Rails 8
      post user_session_path, params: {
        user: {
          email: user.email,
          password: user.password
        }
      }
      follow_redirect! if response.redirect?
    end
    
    def sign_out(user = nil)
      delete destroy_user_session_path
      follow_redirect! if response.redirect?
    end
  end
end
