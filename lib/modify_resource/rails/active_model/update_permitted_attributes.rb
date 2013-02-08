module ActiveModel
  
  # This variable is to aid models methods that need the current user.
  # It is very different from solutions that use Thread --
  # 1. First of all, it's paired with modify_resource_with, and
  # 2. I've hooked into after_save to double-ensure that the 
  #    @as_user variable is unset after any change.
  
  module UpdatePermittedAttributes    
    def update_permitted_attributes(attributes)
      if attributes.all_permitted?
        update_attributes(attributes, without_protection: true)
      else
        update_attributes(attributes)
      end
    end
    
    def deep_attributes=(attributes)
      attributes.each do |key, value|
        next unless key.to_s[m = /_attributes$/]
        nested = self.send key.gsub(m, '')
        if nested.respond_to? :each
          self.send(nested).each do |built|
            value.map { |sub_params| built.attributes = sub_params }
          end
          attributes.delete(key)
        else
          nested.attributes = value
        end
      end
      self.attributes = attributes
      save
    end
    
    # Hook into models that accept nested attributes.
    module ClassMethods
      
      def accepts_nested_attributes_for(field, options={})
        
        before_validation do
          return unless @as_user.present?
          child = self.send(field)

          # Copy down the chain as needed.
          # As_user will be unset on both models after save.
          if child.respond_to? :map
            children = child
            children.map {|c| c.as_user = @as_user }
          else
            child.try(:as_user=, @as_user)
          end
        end
        
        super(field, options)
      end
      
    end
    
    # Add/override statechanging methods to ensure @as_user is unset
    def self.included(base)
      # We need ActiveModel callbacks
      base.extend ActiveModel::Callbacks
      
      # Add our stuff
      base.send :attr_accessor, :as_user
      base.extend ClassMethods
      
      [:after_save, :after_destroy].each do |m|
        base.send(m) do
          self.as_user = nil
        end
      end
    end
  end
  
end

ActiveRecord::Base.send :include, ActiveModel::UpdatePermittedAttributes

class Hash
  
  def all_permitted?
    self.each do |key, value|
      if value.is_a?(Hash)
        return true unless value.respond_to? :all_permitted? # For those without security enabled.
        return false if !value.all_permitted? and !key.numeric?
      end
    end
  end
end