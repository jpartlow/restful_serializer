# This file is part of restful_serializer.  Copyright 2011 Joshua Partlow.  This is free software, see the LICENSE file for details.

module Restful
  module Configuration

    # Provides a register constructor which takes a block,
    # exposing the created instance for fine grained configuration.
    #
    # A class including configurable should declare one or more
    # options using the +option+ class macro.
    #
    # It expects a single option Hash for initialization.
    #
    # If you override initialize, you must call super(option_hash).
    #
    # A Configurable should allow an initialize with no arguments if
    # it is going to be an element of an another Configurable's Hash
    # or Array option.  See (Option#generate_from)
    module Configurable
      
      def self.included(base)
        base.class_eval do
          extend ClassMethods
          class_attribute :options
          self.options = []
        end
      end

      module ClassMethods
        # Constructor which takes a block, exposing the new instance
        # for fine grained configuration
        def register(*args, &block)
          instance = new(*args)
          yield(instance) if block_given?
          return instance 
        end

        def option(name, *args)
          option = Restful::Configuration::Option.new(name, *args)
          self.options << option
          class_eval do
            define_method(option.name) do
              config[option.name]
            end

            define_method(option.mutator_method) do |value|
              _was_explicitly_set(option.name)
              config[option.name] = option.generate_from(value)
            end
          end
        end
      end

      def initialize(options = {})
        options = (options || {}).symbolize_keys
        set(options)
      end

      # Clears the current configuration. 
      def reset
        @config = nil
        @explicitly_set = nil
        options.each do |opt|
          self.config[opt.name] = opt.initialized
        end
      end

      # Clears the current configuration and resets with the passed options.
      def set(options)
        reset
        _set(options)
      end
     
      # Returns a plain deeply duplicated Hash with all options as key/values.
      # Deeply converts all Configurable nodes to hash as well.
      #
      # * to_hash_options
      #   * :ignore_empty => if +ignore_empty+ is set to true, will not include
      #   options that point to empty containers.  (Default false)
      #   * :skip_defaults => if +skip_defaults+ is set to true, will not include
      #   options that are passively set to their default value.  Options actively
      #   set to their default value during initialization should remain. (Default false)
      def to_hash(to_hash_options = {})
        to_hash_options = (to_hash_options || {}).symbolize_keys
        ignore_empty = to_hash_options[:ignore_empty] || false
        skip_defaults = to_hash_options[:skip_defaults] || false

        deeply_dup = lambda do |element|
          return case element
            when Configurable then element.to_hash(to_hash_options)
            when Array then element.map { |e| deeply_dup.call(e) }
            when Hash then
              duped = element.dup
              duped.each { |k,v| duped[k] = deeply_dup.call(v) }
              duped
            else element 
          end
        end

        config_hash = {} 
        config.each do |key,value|
          next if skip_defaults && !value.nil? && !explicitly_set?(key) && find_option(key).default == value

          duplicated = deeply_dup.call(value)
          unless ignore_empty && duplicated.respond_to?(:empty?) && duplicated.empty?
            config_hash[key] = duplicated
          end
        end
        return config_hash
      end

      # A configurable equals another configurable if they are of the same class and
      # their configurations are equal.
      def ==(other)
        return false unless other.class <= self.class
        return self.config == other.config 
      end

      # Equal Configurables should have equal hashes.
      def hash
        return config.hash
      end

      def deep_clone
        Marshal.load(Marshal.dump(self))
      end

      # Produces a new Configurable deeply merged with the passed Configurable or Hash
      # According to the semantics of the +deep_merge+ gem's deep_merge! call.
      # If the Configurable or Hash has options unknown to this Configurable, ArgumentErrors
      # will be raised.
      #
      # Empty container options and defaulted options are skipped.
      def deep_merge!(other)
        other_hash = case other
          when Configurable then other.to_hash(:ignore_empty => true, :skip_defaults => true)
          else other
        end

        hash = to_hash(:ignore_empty => true, :skip_defaults => true)
        new_configurable = self.class.new
        hash._rs_deep_merge!(other_hash)
        return new_configurable.set(hash)
      end

      def option_names
        options.map { |o| o.name }
      end

      # Lookup option by name.
      def find_option(name)
        return options.find { |o| o.name == name }
      end

      # True if the option was explicitly set by passing in a value (as opposed
      # to passively set by default).
      def explicitly_set?(option_name)
        explicitly_set.include?(option_name.to_sym)
      end

      protected

      def config
        @config ||= {}
      end

      # Array of all option names which have been set by initialization options or through mutators.
      # (not by default)
      def explicitly_set
        @explicitly_set ||= []
      end

      def _set(new_options)
        new_options.each do |k,v|
          option = find_option(k)
          raise(ArgumentError, "#{self}#_set: Unknown option: #{k}. (known options: #{option_names.inspect})") unless option
          _was_explicitly_set(k)
          send(option.mutator_method, v)
        end
        return self
      end

      def _was_explicitly_set(option_name)
        explicitly_set << option_name.to_sym
      end

    end

    # Named option
    #
    # * :name => the name of the option, for use when configuring
    # * :type => a default type for a complex option (like an Array, Hash or Resource)
    # * :element_type => specifies the type for elements of a container like an
    #   Array or Hash
    # * :default => if no type is given, may provide a default (such as +false+
    #   or +:value+)
    class Option
      attr_accessor :name, :default
      attr_writer :type, :element_type

      def initialize(name, options = {})
        options = (options || {}).symbolize_keys

        self.name = name.to_sym
        self.type = options[:type]
        self.element_type = options[:element_type]
        self.default = options[:default]
      end

      def mutator_method
        "#{name}="
      end

      def type
        # lazy initialization
        @type_class ||= _to_class(@type)
      end

      def element_type
        @element_type_class ||= _to_class(@element_type)
      end

      # Constructs a new option instance of the given type (or nil)
      def initialized 
        case
          when type then type.new
          else default
        end
      end

      # Generates a new option value from the given configuration.  If
      # type/element_type are configured this will generate new options of the
      # given type from passed configuration Hashes.
      def generate_from(value)
        if type.nil?
          value
        elsif type <= Configurator
          case value
            when Hash then type.new(value)
            when Configurator then value
            else raise(ArgumentError, "Expected option '#{name}' to be of type '#{type}', but received '#{value}'")
          end
        elsif type <= Array
          case value
            when Array
              element_type ? value.map { |e| _element_of_type(e) } : value
            else Array(value)
          end
        elsif type <= Hash
          case value
            when Hash
              if element_type
                value.inject({}) do |hash,row| 
                  hash[row[0].to_sym] = _element_of_type(row[1])
                  hash
                end
              else
                value.symbolize_keys
              end
            when Array then value.inject({}) { |hash,v| hash[v] = nil; hash }
            else { value => nil }
          end
        else
          # A type we don't handle
          value
        end
      end

      private

      # Generates a new element of element_type class
      def _element_of_type(option_hash)
        return element_type <= Restful::Configuration::Configurable ?
          # Bypass any custom initialization and use Configurable#set(options)
          element_type.new.set(option_hash) :
          element_type.new(option_hash) 
      end

      def _to_class(type)
        case type
          when String, Symbol then type.to_s.classify.constantize
          else type
        end
      end
    end

    class Configurator 
      include Configurable
    end

    # Configuration object for one web service.
    #
    # = Options
    #
    # * :name => the name of the web service
    #
    # * :api_prefix => used to supply a prefix to generated name_route methods if method
    #   names cannot be inferred purely by resource class names.
    #
    #  A web service for Reservation might prefix with :guest_api, so the named routes would
    #  be +guest_api_reservations_url+ rather than reservations_url, which might instead
    #  return a path for accessing a Reservation through an HTML interface (perhaps through
    #  a separate controller...)
    #
    # * :default_url_options => ActionController::UrlWriter requires a hash of default
    #   url options (notable { :host => 'foo.com' }).  This can be set per WebService
    #   and globally via Restful.default_url_options.
    #
    # = Resources
    #
    # Resources configurations are set with a call to +register_resource+.
    class WebService < Configurator
      option :name
      option :api_prefix
      option :default_url_options, :type => :hash
      option :resources, :type => :hash, :element_type => 'Restful::Configuration::Resource'

      def initialize(name, options = {})
        super(options.merge(:name => name))
      end

      # Adds a Restful::Configuration::Resource.
      def register_resource(name, options = {}, &block)
        resources[name] = Resource.register(options, &block)
      end

      # Returns a deep clone of the requested resource looked up by the passed key.
      # Key may be a symbol, string, Class or instance of Class of the resource.
      def resource_configuration_for(resource_key)
        resource = case resource_key 
          when Symbol
            resources[resource_key]
          when String
            resources[resource_key.to_sym]
          when Class
            resources[resource_key.name.underscore.to_sym]
          else
            resources[resource_key.class.name.underscore.to_sym]
        end
        return resource.nil? ? nil : resource.deep_clone
      end
    end

    # Configuration object for one resource.
    #
    # = Options
    #
    # The following options may be set for each resource configured on a web service:
    #
    # * :name_method => method to call on an instance to produce a human meaningful
    #   reference for the instance.  Defaults to :name.
    # * :serialization => options to be passed to a
    #   Restful::Configuration::ARSerialization to configure serialization of the
    #   ActiveRecord instance itself.
    # * :url_for => if the named_route helper method cannot be guessed from normal
    #   Rails restful syntax, it may be overriden here.
    # * :associations => you may include href references to the instance's
    #   associations.  This can be a single association, a simple array of
    #   assocations, or a hash of association href keys to assocation names.  If
    #   this is set as a hash, then the key is the name of the href (without
    #   '_href'), and the value is the model association name.  If value is nil,
    #   then key is assumed to be both.
    # * :shallow => if you are serializing an association, by default member
    #   includes and association references are stripped.  Set this to false to
    #   traverse deeply.
    # * :no_inherited_options => normally a subclass inherits and merges into its
    #   base class settings.  Setting this to true prevents this so that only the
    #   options specifically set for the class will be used.  Default false.
    #
    class Resource < Configurator
      option :name_method, :default => :name
      option :url_for
      option :associations, :type => :hash
      option :serialization, :type => 'Restful::Configuration::ARSerialization'
      option :no_inherited_options, :default => false
      option :shallow, :default => false

      alias_method :serialization_without_block, :serialization 
      def serialization(&block)
        if block_given?
          yield(serialization_without_block)
        end        
        return serialization_without_block
      end
    end

    # Configuration for the ActiveRecord::Serialization::Serializer
    # of one activerecord class.
    #
    # = Options
    #
    # * :only => an attribute name or an array of attribute names.  Defines which
    #   attributes will be serialized.
    # * :except => an attribute name or an array of attribute names.  All attributes
    #   except these will be serialized.  Inverse of :only.  :only takes precedence.
    # * :include => nested ARSerialization definitions for associations.
    # * :methods => an method name or an array of method names to be included in the
    #   serialization.
    #
    # See ActiveRecord::Serialization.to_json for more details
    class ARSerialization < Configurator
      option :only, :type => :array
      option :except, :type => :array 
      option :include, :type => :hash, :element_type => 'Restful::Configuration::ARSerialization'
      option :methods, :type => :array

      # Allows you to configure an included ARSerialization instance.
      # Expects a block.
      def includes(name, options = {}, &block)
        self.include[name] = ARSerialization.register(options, &block)
      end
    end
  end
end
