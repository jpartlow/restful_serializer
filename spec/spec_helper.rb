$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'rubygems'
require 'action_controller'
require 'database'

require 'spec'
require 'spec/autorun'
require 'pp'

require 'restful'

# These routes are only required by some tests, but route generation issues crop
# up depending on the order in which restful/* files are required.  The reasons
# are mysterious, though they may have something to do with ActionController::UrlWriter
ActionController::Routing::Routes.clear!
ActionController::Routing::Routes.draw do |map|
  map.resources :foos
  map.prefix_foo 'prefix/foos/:id', :controller => 'foos', :action => 'show'
  map.custom_foo 'custom_foo/:id', :controller => 'foos', :action => 'show'
  map.resources :bars do |bars|
    bars.resources :dingos
  end 
  map.resources :things
end

#class TestLogger
#  [:debug, :info, :warn, :error].each do |m|
#    define_method(m) { |message| puts "#{m.to_s.upcase}: #{message}" }
#  end
#end

Spec::Runner.configure do |config|

end
