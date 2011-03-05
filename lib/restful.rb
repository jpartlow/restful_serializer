# This file is part of Restful.  Copyright 2011 Joshua Partlow.  This is free software, see the LICENSE file for details.
require 'active_support'
require 'restful/serializer'

# This library is used to decorate ActiveRecord with methods to assist in generating 
# Restful content for Web Services.
#
# Currently it assumes JSON.
#
# = Usage
#
#   # :name => :string
#   # :age  => :int
#   class Person < ActiveRecord::Base
#
#     restful 
#
#   end
#
#   inst = Person.new(:name => 'Bob', :age => 41)
#   inst.id # => 1
#   inst.to_href # => 'http://www.example.com/people/1'
#   inst.to_json(:restful => true)
#   # => "{ 'person' : { 'id' : 1, 'name' : 'Bob', 'age' : 17, 'href' : 'http://www.example.com/web_service/people/1' } }"
#
module Restful
  # Route prefix for api calls.
  mattr_accessor :api_prefix

  # Hash for configuration Restful models.
  mattr_accessor :model_configuration
  self.model_configuration = {}

  def self.model_configuration=(options)
    @@model_configuration = options.symbolize_keys
  end

  def self.model_configuration_for(key)
    config = case key 
      when Symbol
        model_configuration[key]
      when String
        model_configuration[key.to_sym]
      when Class
        model_configuration[key.name.underscore.to_sym]
      else
        model_configuration[key.class.name.underscore.to_sym]
    end
    return config || {} 
  end

  module Extensions
    def restful(*args)
      Restful::Serializer.new(self, *args).serialize
    end
  end
end
ActiveRecord::Base.send(:include, Restful::Extensions)
