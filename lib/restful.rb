# This file is part of restful_serializer.  Copyright 2011 Joshua Partlow.  This is free software, see the LICENSE file for details.
#require 'restful/configuration'

# This library is used to decorate ActiveRecord with methods to assist in generating 
# Restful content for Web Services.
#
# It produces a hash of reference, object and href information for an
# ActiveRecord instance or association.  Output is highly configurable both
# through Rails initialization and method calls.
#
# = Options
#
# The following options may be set in the Restful.model_configuration hash on a
# per model class basis.
#
# * :name => method to call on an instance to produce a human meaningful
#   reference for the instance.  Defaults to :name.
# * :serialization => options to be passed to
#   ActiveRecord::Serialization::Serializer to configure serialization of the
#   ActiveRecord instance itself.  See ActiveRecord::Serialization.to_json
# * :url_for => if the named_route helper method cannot be guessed from normal
#   Rails restful syntax, it may be overriden here.
# * :associations => you may include href references to the instance's associations
# * :shallow => if you are serializing an association, by default member
#   includes and association references are stripped.  Set this to false to
#   traverse deeply.
# * :no_inherited_options => normally a subclass inherits and overrides its
#   base class settings.  Setting this to true prevents this so that only the
#   options specifically set for the class will be used.  Default false.
#
# = Usage
#
#   # :first_name => :string
#   # :last_name => :string
#   # :age  => :int
#   # :secrets => :string
#   class Person < ActiveRecord::Base
#     has_many :books
#  
#     def name
#       "#{first_name} #{last_name}"
#     end
#   end
#
#   # :title => :string
#   # :pages => :int
#   # :person_id => :int
#   class Book < ActiveRecord::Base
#     belongs_to :person
#   end
#
#   ActionController::Routing::Routes.draw do |map|
#     map.resources :people do |people|
#       people.resources :books
#     end 
#   end
#
#   Restful.model_configuration = {
#     :person => {
#       :serialization => { :except => [:secrets] }
#       :associations => :books,
#     }
#     :book => {
#       :name => :title,
#       :associations => :person,
#     }
#   }
#
#   bob = Person.new(:first_name => 'Bob', :last_name => 'Smith', :age => 41,
#     :secrets => 'untold')
#   bob.restful
#   # => { 
#   #   'name' => 'Bob Smith'
#   #   'person' => { 
#   #      'id' => 1,
#   #      'first_name' => 'Bob',
#   #      'last_name' => 'Bob',
#   #      'age' : 17,
#   #   },
#   #   'href' => 'http://www.example.com/web_service/people/1' }
#   #   'books_href' => 'http://www.example.com/web_service/people/1/books' }
#   # }
#
# Options may be overridden at call time, by default this overwrites the passed
# options completely:
#  
#   bob = Person.new(:first_name => 'Bob', :last_name => 'Smith', :age => 41,
#     :secrets => 'untold')
#   bob.restful(:serialization => { :except => [:id] })
#   # => { 
#   #   'name' => 'Bob Smith'
#   #   'person' => { 
#   #      'first_name' => 'Bob',
#   #      'last_name' => 'Bob',
#   #      'age' : 17,
#   #      'secrets' : 'untold',
#   #   },
#   #   'href' => 'http://www.example.com/web_service/people/1' }
#   #   'books_href' => 'http://www.example.com/web_service/people/1/books' }
#   # }
#
# To perform a deep merge of options instead, place the options to be deeply merged
# inside a :deep_merge hash:
#
#   bob = Person.new(:first_name => 'Bob', :last_name => 'Smith', :age => 41,
#     :secrets => 'untold')
#   bob.restful(:deep_merge => { :serialization => { :except => [:id] } })
#   # => { 
#   #   'name' => 'Bob Smith'
#   #   'person' => { 
#   #      'first_name' => 'Bob',
#   #      'last_name' => 'Bob',
#   #      'age' : 17,
#   #   },
#   #   'href' => 'http://www.example.com/web_service/people/1' }
#   #   'books_href' => 'http://www.example.com/web_service/people/1/books' }
#   # }
#
# These two techniques can be combined, but overwriting will occur prior to a deep merge...
#
# There is a trap in how deep merge handles this.  If the above :except values had
# not been configured as arrays, then deep merge would have overwritten rather than merging
# them.  This could probably be adjusted with a closer look into the deep_merge docs.
#
# We also don't have 'knockouts' configured yet to signal remove of a particular item.
module Restful
  # Requiring Serializer (and hence action_controller for UrlWriter) was interferring with
  # route generation somehow, so instead we are letting it autoload if used.
  autoload :Serializer, 'restful/serializer'
  autoload :Configuration, 'restful/configuration'

  # Default url options for ActionController::UrlWriter.
  # (Generally you must provide {:host => 'example.com'})
  mattr_accessor :default_url_options
  self.default_url_options = {}

  # Hash of registered Restful::Configuration::WebService configurations. 
  mattr_accessor :registered_web_services
  self.registered_web_services = {}

  class << self

    # Configured the specified web service.
    def register_web_service(name, options = {}, &block)
      @@registered_web_services[symbolized_web_service_name(name)] = new_ws = Restful::Configuration::WebService.register(name, options, &block)
      return new_ws
    end

    # Retrieve configuration for the specified web service. 
    def web_service_configuration(key)
      ws = @@registered_web_services[symbolized_web_service_name(key)]
      if ws.default_url_options.empty? && !default_url_options.empty?
        ws.default_url_options = default_url_options.dup
      end if ws
      return ws
    end

    def symbolized_web_service_name(name)
      return if name.nil?
      name.to_s.downcase.gsub(/[^\w]+/,'_').to_sym
    end

    def clear
      self.default_url_options = {}
      self.registered_web_services = {}
    end
  end

  module Extensions

    # Restfully serialize an activerecord object, association or a plain array of activerecord objects.
    # The web service name must be specified as registered via Restful.register_web_service, unless there
    # is only one registered service.
    #
    # A final hash of options will be passed on to the serializer for configuration.
    #
    # If a block is given, the serializer's Restful::Configuration::Resource configuration object will
    # be exposed for fine grained configuration.
    def restful(*args, &block)
      options = args.extract_options!
      web_service_name = args.shift
      web_service = Restful.web_service_configuration(web_service_name)
      web_service ||= Restful.registered_web_services.values.first if Restful.registered_web_services.size == 1
      Restful::Serializer.new(self, web_service, options, &block).serialize
    end
  end
end
ActiveRecord::Base.send(:include, Restful::Extensions)
ActiveRecord::Associations::AssociationProxy.send(:include, Restful::Extensions)
Array.send(:include, Restful::Extensions)
