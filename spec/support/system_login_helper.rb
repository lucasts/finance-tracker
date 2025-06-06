# spec/support/system_login_helper.rb
module SystemLoginHelper
  def login_as(user)
    visit new_user_session_path
    fill_in 'Email', with: user.email
    fill_in 'Senha', with: user.password
    click_button 'Entrar'
  end
end

RSpec.configure do |config|
  config.include SystemLoginHelper, type: :system
end
