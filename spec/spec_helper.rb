$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

ENV['RAILS_ENV'] = 'test'

require 'rubygems'
gem 'actionpack', '>=3.0.0' 
gem 'activesupport', '>=3.0.0' 
gem 'activerecord', '>=3.0.0'
gem 'railties', '>=3.0.0'

# Only the parts of rails we want to use
# if you want everything, use "rails/all"
require "action_controller/railtie"
 
# Define the application and configuration
module RestfulTest 
  class Application < ::Rails::Application
    # configuration here if needed
    config.active_support.deprecation = :stderr
  end
end
 
# Initialize the application
RestfulTest::Application.initialize!

require 'rspec'

RSpec.configure do |config|

end

require 'database'
require 'pp'
require 'restful'
