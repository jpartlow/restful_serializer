# This file is part of Restful.  Copyright 2011 Joshua Partlow.  This is free software, see the LICENSE file for details.
#require 'action_pack'
require 'active_record'
require 'action_controller'
#require 'action_controller/resources'
#require 'action_controller/routing'
#require 'action_controller/url_rewriter'

module Restful
  class Serializer
    include ActionController::UrlWriter
    attr_accessor :subject, :klass, :options
  
    def initialize(subject, *args)
      self.subject = subject
      local_options = args.pop || {}
      self.options = Restful.model_configuration_for(subject).merge(local_options.symbolize_keys)
      self.klass = options[:class]
       
      puts client_api_teams_url
    end
  
    def serialize
      singular_url_for_method = [Restful.api_prefix,klass,'url'].join('_').downcase
      restful = {
        'name' => subject.name,
        klass.to_s => ActiveRecord::Serialization::Serializer.new(subject, options[:serialization]).serializeable_record,
      }
      restful['href'] = send(singular_url_for_method, subject.id) if respond_to?(singular_url_for_method)
      return restful
    end
  end
end
