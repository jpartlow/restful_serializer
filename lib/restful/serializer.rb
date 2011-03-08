# This file is part of restful_serializer.  Copyright 2011 Joshua Partlow.  This is free software, see the LICENSE file for details.
require 'active_record'
require 'action_controller'

module Restful
  class Serializer
    include ActionController::UrlWriter
    attr_accessor :subject, :klass, :options, :shallow
  
    def initialize(subject, *args)
      self.subject = subject
      local_options = args.pop || {}
      self.options = Restful.model_configuration_for(subject).merge(local_options.symbolize_keys)
      self.klass = (options[:class] || subject.class.name).to_s.underscore
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
      ar_options = (options[:serialization] || {}).dup
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
        url_for = [options[:url_for], 'url'] if options.include?(:url_for)
        url_for ||= [Restful.api_prefix,klass,'url']
        url_for = url_for.compact.join('_').downcase
        @href = send(url_for, subject.id) if respond_to?(url_for)
      end
      return @href
    end

    private

    def _serialize_active_record
      restful = {
        klass => ActiveRecord::Serialization::Serializer.new(subject, active_record_serialization_options).serializable_record,
      }
      restful['name'] = name
      restful['href'] = href
      associations.each do |association|
        restful["#{association.name}_href"] = association.href 
      end unless shallow

      return restful
    end

    def _serialize_array
      restful = subject.map do |e|
        array_options = options.dup
        array_options.merge!(:shallow => true) unless array_options.include?(:shallow)
        Serializer.new(e, array_options).serialize
      end 
      return restful 
    end
  end

  module UrlForHelpers

    def get_url_for(name_elements, *args)
      url_for = [Restful.api_prefix,name_elements,'url'].flatten.compact.join('_').downcase
      send(url_for, *args) if respond_to?(url_for) 
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
        href = get_url_for(association_name, subject.send(association.name).id)
      else
        href = collective_href
      end
      return href
    end

    def collective_href
      # try url_for nested resources first
      unless href = get_url_for([subject_klass, association_name], subject.id)
        href = get_url_for(association_name)
      end
      return href 
    end
  end
end
