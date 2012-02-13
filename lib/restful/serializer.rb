# This file is part of restful_serializer.  Copyright 2011 Joshua Partlow.  This is free software, see the LICENSE file for details.
require 'forwardable'

module Restful

  # Enables local generation of named_routes with preset arguments:
  #
  # * :api_prefix
  # * :default_url_options
  #
  # Used by Serializer and Association to customize urls for their WebService.
  class UrlFactory
    attr_accessor :api_prefix, :default_url_options

    def initialize(options)
      self.api_prefix = options[:api_prefix]
      self.default_url_options = options[:default_url_options] || {}
    end

    # Url.for but with UrlFactory's options slipped in.
    def create(options)
      create_options = {:api_prefix => api_prefix}.merge(options).deep_merge(:named_route_options => default_url_options)
      Url.for(create_options)
    end
  end

  # Used to construct and attempt to call named routes by providing resource
  # strings out of which a named route method name will be constructed:
  #
  # Options:
  #
  # * :api_prefix => if we are constructing an url helper from a collection of
  #   resource names, prepend it with this prefix
  # * :resources => a symbol, string or array of same describing segments of
  #   the helper method name.  e.g. [:user, :comments] => user_comments (to
  #   which _url will be appended...)
  # * :method => overrides the use of :resources and :api_prefix
  # * :named_route_options => any additional options to be passed to the
  #   named_route when it is called (:id or :host for instance)
  #   
  # = Example
  #
  #   Url.for(:api_prefix => :foo_service, :resources => [:user, :comments],
  #     :named_route_options => {:id => 1})
  #
  #   # => send("foo_service_user_comments_url", {:id => 1})
  #   # which if it exists is likely to return something like:
  #   # "http://example.com/user/1/comments"
  #
  class Url
    include Rails.application.routes.url_helpers
    @@initialized = false

    attr_accessor :options

    class << self
   
      # Sets ActionController::UrlWriter.default_url_options from
      # Restful.default_url_options.  Attempting to do this during Rails
      # initialization results in botched routing, presumably because of how
      # ActionController::UrlWriter initializes when you include it into a
      # class.  So this method is called lazily. 
      def initialize_default_url_options
        unless @@initialized
          self.default_url_options = Restful.default_url_options
          @@initialized = true
        end
      end

      # Helper for generating url strings from resource options.
      def for(options)
        new(options).to_s
      end
    end

    def initialize(options)
      self.options = options
      Url.initialize_default_url_options
    end

    def to_s
      url_for = [options[:method], 'url'] if options.include?(:method)
      url_for ||= [options[:api_prefix], options[:resources], 'url'].flatten.compact
      url_for = url_for.join('_').downcase
      send(url_for, *Array(options[:args])) if respond_to?(url_for) 
    end

  end

  # Provides some utility functions for acting deeply on hashes.
  class DeepHash < ::Hash

    class << self
      def deeply_stringify_keys!(object)
        case object 
          when ::Hash 
            then
              object.stringify_keys!
              recurse_on = object.values
          when Array then recurse_on = object
        end
        recurse_on.each do |member|
          deeply_stringify_keys!(member)
        end if recurse_on
        return object 
      end
    end

    # Walks the graph, and destructively applies stringify_keys!
    def deeply_stringify_keys!
      return DeepHash.deeply_stringify_keys!(self)
    end
  end

  # New instances of Serializer handle the actual conversion of a model subject into
  # a hash of resource attributes.
  #
  # = Configuration
  #
  # There are four levels of configuration.
  #
  # 1. The subject's base_class configuration (if different than it's own class configuration)
  # 2. The subject's class configuration
  # 3. Any additional parameters passed into the initialization of the Serializer.  
  # 4. Any configuration performed when the Restful::Configuration::Resource is yielded
  #    to a passed block in initialization.
  #
  # One through three are successively deep_merged.  Four allows for complete redefinition.
  class Serializer
    extend Forwardable

    attr_accessor :subject, :base_klass, :klass, :options, :configure_block
    attr_accessor :web_service, :resource_configuration, :url_factory

    def_delegators :@web_service, :api_prefix, :default_url_options
    def_delegator :@resource_configuration, :associations, :resource_associations
    def_delegators :@resource_configuration, :serialization, :url_for, :no_inherited_options, :shallow, :name_method

    def initialize(subject, web_service, options = {}, &block)
      self.subject = subject
      self.web_service = web_service || Restful::Configuration::WebService.new('__stub__')
      raise(ArgumentError, "No web service configuration set.  Received: #{web_service.inspect})") unless web_service.kind_of?(Restful::Configuration::WebService)

      self.base_klass = subject.class.base_class.name.demodulize.underscore if subject.class.respond_to?(:base_class)
      self.klass = subject.class.name.demodulize.underscore

      self.options = (options || {}).symbolize_keys
      if subject.kind_of?(Array)
        # preserve configure block to pass to array members 
        self.configure_block = block
      else
        _configure(&block)
      end
    
      self.url_factory = UrlFactory.new(:api_prefix => api_prefix, :default_url_options => default_url_options)
    end
 
    # Encode as a resource hash. 
    def serialize
      case 
        when subject.respond_to?(:attribute_names) then _serialize_active_record
        when subject.kind_of?(Array) then _serialize_array
        else ActiveSupport::JSON.decode(subject.to_json) # just capture the hash of the object structure
      end
    end

    def active_record_serialization_options
      ar_options = serialization.to_hash(:ignore_empty => true)
      ar_options.delete(:include) if shallow 
      return ar_options
    end

    def name
      subject.send(name_method) if subject.respond_to?(name_method)
    end

    def associations
      unless @associations
        @associations = case resource_associations
          when Array,Hash
            resource_associations.map do |name,assoc|
              Association.new(subject, klass, (assoc.nil? ? name : assoc), url_factory, name)
            end
          when nil
            []
          else
            [Association.new(subject, klass, resource_associations, url_factory)]
        end
      end
      return @associations
    end

    def href 
      unless @href
        @href = url_factory.create(:method => url_for, :args => subject.id) if url_for
        @href = url_factory.create(:resources => klass, :args => subject.id) unless @href
        @href = url_factory.create(:resources => base_klass, :args => subject.id) unless @href || base_klass == klass
      end
      return @href
    end

    private

    def base_configuration
      unless @base_configuration
        @base_configuration = web_service.resource_configuration_for(base_klass) if web_service
        @base_configuration ||= Restful::Configuration::Resource.new
      end
      return @base_configuration
    end

    def class_configuration
      unless @class_configuration
        @class_configuration = web_service.resource_configuration_for(klass) if web_service
        @class_configuration ||= Restful::Configuration::Resource.new
      end
      return @class_configuration
    end

    def passed_configuration
      return @passed_configuration ||= Restful::Configuration::Resource.new(options)
    end

    def _configure(&block)
      self.resource_configuration = 
        (klass == base_klass || class_configuration.no_inherited_options) ? 
          class_configuration.deep_clone :
          base_configuration.deep_merge!(class_configuration)

      self.resource_configuration = resource_configuration.deep_merge!(passed_configuration)

      yield(resource_configuration) if block_given?

      return resource_configuration
    end

    def _serialize_active_record
      restful = DeepHash[
        klass => ActiveRecord::Serialization::Serializer.new(subject, active_record_serialization_options).serializable_record
      ]
      restful['name'] = name if name
      restful['href'] = href
      associations.each do |association|
        restful["#{association.name}_href"] = association.href 
      end unless shallow

      return restful.deeply_stringify_keys!
    end

    def _serialize_array
      restful = subject.map do |e|
        array_options = options.clone
        array_options = { :shallow => true }.merge(array_options)
        Serializer.new(e, web_service, array_options, &configure_block).serialize
      end 
      return restful 
    end
  end

  # Handle for information about an ActiveRecord association.
  class Association
    attr_accessor :name, :association_name, :association, :subject, :subject_klass, :url_factory
    
    def initialize(subject, subject_klass, association_name, url_factory, name = nil)
      self.subject = subject
      self.subject_klass = subject_klass
      self.association_name = association_name
      self.url_factory = url_factory
      self.name = name || association_name
      self.association = subject.class.reflect_on_association(association_name)
    end

    def singular?
      [:belongs_to, :has_one].include?(association.macro)
    end

    def href
      if singular?
        href = url_factory.create(:resources => association_name, :args => subject.send(association.name).id)
      else
        href = collective_href
      end
      return href
    end

    def collective_href
      # try url_for nested resources first
      unless href = url_factory.create(:resources => [subject_klass, association_name], :args => subject.id)
        href = url_factory.create(:resources => association_name)
      end
      return href 
    end
  end
end
