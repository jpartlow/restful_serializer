$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'rubygems'
require 'action_controller'
require 'database'

require 'spec'
require 'spec/autorun'
require 'pp'

require 'restful'

#class TestLogger
#  [:debug, :info, :warn, :error].each do |m|
#    define_method(m) { |message| puts "#{m.to_s.upcase}: #{message}" }
#  end
#end

Spec::Runner.configure do |config|

end
