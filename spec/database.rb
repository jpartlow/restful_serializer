require 'rubygems'

gem 'activerecord', '>=3.0.0'
require 'active_record'
require 'logger'

ActiveRecord::Base.establish_connection({'adapter' => 'sqlite3', 'database' => ':memory:'})
ActiveRecord::Base.logger = Logger.new("#{File.dirname(__FILE__)}/active_record.log")

def create_schema(&block)
  connection = ActiveRecord::Base.connection
  yield connection if block_given?
end
