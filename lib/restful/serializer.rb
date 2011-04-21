# This file is part of restful_serializer.  Copyright 2011 Joshua Partlow.  This is free software, see the LICENSE file for details.
require 'active_record'
require 'action_controller'
require 'deep_merge'

module Restful
  module UrlForHelpers

    # Used to construct and attempt to call named routes be providing resource
    # strings out of which a named route method name will be constructed:
    #
    # Options:
    #
    # * :resources => a symbol, string or array of same describing segments of
    #   the helper method name.  e.g. [:user, :comments] => user_comments (to
    #   which _url will be appended...)
    # * :method => overrides the use of :resources and :prefix
    # * :args => any arguments to be passed to the named_route when it is called
    #
    # = Example
    #
    #   get_url_for(:resources => [:user, :comments], :args => 1)
    #   # => send("#{Restful.api_prefix}_user_comments_url", 1)
    #   # which if it exists is likely to return something like:
    #   # "http://example.com/user/1/comments"
    #
    def get_url_for(options)
      url_for = [options[:method], 'url'] if options.include?(:method)
      url_for ||= [Restful.api_prefix, options[:resources], 'url'].flatten.compact
      url_for = url_for.join('_').downcase
      send(url_for, *Array(options[:args])) if respond_to?(url_for) 
    end

  end

  class Serializer
    include ActionController::UrlWriter
    include UrlForHelpers
    attr_accessor :subject, :base_klass, :klass, :options, :shallow
  
    def initialize(subject, *args)
      self.subject = subject

      self.base_klass = subject.class.base_class.name.demodulize.underscore if subject.class.respond_to?(:base_class)
      self.klass = subject.class.name.demodulize.underscore

      passed_options = (args.pop || {}).symbolize_keys
      if subject.kind_of?(Array)
        # preserve options as is to be passed to array members
        self.options = passed_options
      else
        deeply_merge = passed_options.delete(:deep_merge)
        base_options = Restful.model_configuration_for(base_klass) || {}
        class_options = Restful.model_configuration_for(klass) || {}
        self.options = (klass == base_klass || class_options[:no_inherited_options]) ? 
          class_options : 
          base_options.merge(class_options)
        self.options.merge!(passed_options)
        self.options.deep_merge(deeply_merge) if deeply_merge
      end

      self.shallow = options[:shallow]
    end
  
    def serialize
      case 
        when subject.respond_to?(:attribute_names) then _serialize_active_record
        when subject.kind_of?(Array) then _serialize_array
        else ActiveSupport::JSON.decode(subject.to_json) # just capture the hash of the object structure
      end
    end

    def active_record_serialization_options
      ar_options = (options[:serialization] || {}).clone
      ar_options.delete(:include) if shallow 
      return ar_options
    end

    def name
      name_method = options[:name] || :name
      subject.send(name_method) if subject.respond_to?(name_method)
    end

    def associations
      unless @associations
        @associations = case options[:associations]
          when Array,Hash
            options[:associations].map do |name,assoc|
              Association.new(subject, klass, (assoc.nil? ? name : assoc), name)
            end
          when nil
            []
          else
            [Association.new(subject, klass, options[:associations])]
        end
      end
      return @associations
    end

    def href 
      unless @href
        @href = get_url_for(:method => options[:url_for], :args => subject.id) if options.include?(:url_for)
        @href = get_url_for(:resources => klass, :args => subject.id) unless @href
        @href = get_url_for(:resources => base_klass, :args => subject.id) unless @href || base_klass == klass
      end
      return @href
    end

    private

    def _serialize_active_record
      restful = {
        klass => ActiveRecord::Serialization::Serializer.new(subject, active_record_serialization_options).serializable_record,
      }
      restful['name'] = name if name
      restful['href'] = href
      associations.each do |association|
        restful["#{association.name}_href"] = association.href 
      end unless shallow

      return restful
    end

    def _serialize_array
      restful = subject.map do |e|
        array_options = options.clone
        array_options.merge!(:shallow => true) unless array_options.include?(:shallow)
        Serializer.new(e, array_options).serialize
      end 
      return restful 
    end
  end

  # Handle for information about an ActiveRecord association.
  class Association
    include ActionController::UrlWriter
    include UrlForHelpers
    attr_accessor :name, :association_name, :association, :subject, :subject_klass
    
    def initialize(subject, subject_klass, association_name, name = nil)
      self.subject = subject
      self.subject_klass = subject_klass
      self.association_name = association_name
      self.name = name || association_name
      self.association = subject.class.reflect_on_association(association_name)
    end

    def singular?
      [:belongs_to, :has_one].include?(association.macro)
    end

    def href
      if singular?
        href = get_url_for(:resources => association_name, :args => subject.send(association.name).id)
      else
        href = collective_href
      end
      return href
    end

    def collective_href
      # try url_for nested resources first
      unless href = get_url_for(:resources => [subject_klass, association_name], :args => subject.id)
        href = get_url_for(:resources => association_name)
      end
      return href 
    end
  end
end
