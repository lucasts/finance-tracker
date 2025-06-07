# Rails 8 compatibility helper for Devise authentication in request specs
module DeviseRequestSpecHelper
  def login_user(user)
    post user_session_path, params: {
      user: {
        email: user.email,
        password: user.password || 'password123'
      }
    }
  end
  
  def logout_user
    delete destroy_user_session_path
  end
end

RSpec.configure do |config|
  config.include DeviseRequestSpecHelper, type: :request
end
