require 'machinist'
require 'machinist/blueprints'
require 'dm-core'

module Machinist
  
  class DataMapperAdapter
    def self.has_association?(object, attribute)
      object.class.relationships.has_key?(attribute)
    end
    
    def self.class_for_association(object, attribute)
      association = object.class.relationships[attribute]
      association && association.parent_model
    end

    # This method takes care of converting any associated objects,
    # in the hash returned by Lathe#assigned_attributes, into their
    # object ids.
    #
    # For example, let's say we have blueprints like this:
    #
    #   Post.blueprint { }
    #   Comment.blueprint { post }
    #
    # Lathe#assigned_attributes will return { :post => ... }, but
    # we want to pass { :post_id => 1 } to a controller.
    #
    # This method takes care of cleaning this up.
    def self.assigned_attributes_without_associations(lathe)
      attributes = {}
      lathe.assigned_attributes.each_pair do |attribute, value|
        association = lathe.object.class.relationships[attribute]
        if association && association.options[:max].nil?  # Make sure it's a belongs_to association.
          # DataMapper child_key can have more than one property, but I'm not
          # sure in what circumstances this would be the case. I'm assuming
          # here that there's only one property.
          key = association.child_key.map(&:field).first.to_sym
          attributes[key] = value.id
        else
          attributes[attribute] = value
        end
      end
      attributes
    end
  end

  module DataMapperExtensions
    def make(*args, &block)
      lathe = Lathe.run(Machinist::DataMapperAdapter, self.new, *args)
      unless Machinist.nerfed?
        lathe.object.save || raise("Save failed")
        lathe.object.reload
      end
      lathe.object(&block)
    end

    def make_unsaved(*args)
      returning(Machinist.with_save_nerfed { make(*args) }) do |object|
        yield object if block_given?
      end
    end

    def plan(*args)
      lathe = Lathe.run(Machinist::DataMapperAdapter, self.new, *args)
      Machinist::DataMapperAdapter.assigned_attributes_without_associations(lathe)
    end
  end

end

DataMapper::Model.append_extensions(Machinist::Blueprints::ClassMethods)
DataMapper::Model.append_extensions(Machinist::DataMapperExtensions)