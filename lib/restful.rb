# This file is part of restful_serializer.  Copyright 2011 Joshua Partlow.  This is free software, see the LICENSE file for details.

require 'deep_merge/rails_compat'

# This library is used to decorate ActiveRecord with methods to assist in generating 
# Restful content for Web Services.
#
# It produces a hash of reference, object and href information for an
# ActiveRecord instance or association.  Output is highly configurable both
# through Rails initialization and during method calls.
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
#   Restful.default_url_options(:host => 'www.example.com')
#   Restful.register_web_service(:books) do |config|
#
#     config.register_resource(:person,
#       :serialization => { :except => [:secrets] }
#       :associations => :books
#     )
#
#     config.register_resource(:book,
#       :name_method => :title,
#       :associations => :person
#     )
#
#   end 
#
#   bob = Person.new(:first_name => 'Bob', :last_name => 'Smith', :age => 41,
#     :secrets => 'untold')
#   bob.restful(:books)
#   # => { 
#   #   'name' => 'Bob Smith'
#   #   'person' => { 
#   #      'id' => 1,
#   #      'first_name' => 'Bob',
#   #      'last_name' => 'Bob',
#   #      'age' => 17,
#   #   },
#   #   'href' => 'http://www.example.com/web_service/people/1' }
#   #   'books_href' => 'http://www.example.com/web_service/people/1/books' }
#   # }
#
# Options may be adjusted at call time.
#
# If options are passed in as a hash then they will be merged into the class's
# registered resource configuration (using the +deep_merge+ gem).  
#  
#   bob = Person.new(:first_name => 'Bob', :last_name => 'Smith', :age => 41,
#     :secrets => 'untold')
#   bob.restful(:books, :serialization => { :except => [:id] })
#   # => { 
#   #   'name' => 'Bob Smith'
#   #   'person' => { 
#   #      'first_name' => 'Bob',
#   #      'last_name' => 'Bob',
#   #      'age' => 17,
#   #   },
#   #   'href' => 'http://www.example.com/web_service/people/1' }
#   #   'books_href' => 'http://www.example.com/web_service/people/1/books' }
#   # }
#
# For more fine grained control, the final configuration object is exposed
# if a block is given to the restful call:
#
#   bob = Person.new(:first_name => 'Bob', :last_name => 'Smith', :age => 41,
#     :secrets => 'untold')
#   bob.restful(:books, :serialization => { :except => [:id] }) do |configure|
#
#     pp configure.serialization.except
#     # => [ :secrets, :id ]
#
#     configure.serializtion.except = :id
#
#   end
#   # => { 
#   #   'name' => 'Bob Smith'
#   #   'person' => { 
#   #      'first_name' => 'Bob',
#   #      'last_name' => 'Bob',
#   #      'age' => 17,
#   #      'secrets' => 'untold',
#   #   },
#   #   'href' => 'http://www.example.com/web_service/people/1' }
#   #   'books_href' => 'http://www.example.com/web_service/people/1/books' }
#   # }
#
# These two techniques can be combined.
module Restful
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

    # Restfully serialize an activerecord object, association or a plain array
    # of activerecord objects.  The web service name must be specified as
    # registered via Restful.register_web_service, unless there is only one
    # registered service.
    #
    # A final hash of options will be passed on to the serializer for configuration.
    #
    # If a block is given, the serializer's Restful::Configuration::Resource
    # configuration object will be exposed for fine grained configuration.
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
ActiveRecord::Associations::CollectionProxy.send(:include, Restful::Extensions)
Array.send(:include, Restful::Extensions)
