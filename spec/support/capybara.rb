# frozen_string_literal: true

require 'capybara/rspec'
require 'selenium/webdriver'

Capybara.register_driver :selenium_firefox_headless do |app|
  options = ::Selenium::WebDriver::Firefox::Options.new
  options.add_argument('--headless')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--window-size=1400,1400')
  
  Capybara::Selenium::Driver.new(
    app,
    browser: :firefox,
    options: options
  )
end

Capybara.javascript_driver = :selenium_firefox_headless
Capybara.default_max_wait_time = 5

# Configure server settings for container environment
Capybara.server_host = '0.0.0.0'
Capybara.server_port = 3001
