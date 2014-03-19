module ActionController
  
  module UpdateAs
    
    module ClassMethods
      
      def update_as_current(user_class=:user, nested_resources={})
        append_before_filter do
          return unless [:PUT, :POST, :PATCH].include?(request.method.to_sym) and
                        params[:_method] != "delete"
          
          update_as(self.send(:"current_#{user_class}"), resource, nested_resources)
        end
      end
      
      def update_as_current_user(nested_resources={})
        update_as_current :user, nested_resources
      end
      
    end
    
    def update_as(user, current_resource, nested_resources={})
      case nested_resources
      when Symbol, String, Array
        update_resource(current_resource, Array(nested_resources), as: user)
      else
        return update_resource(current_resource, as: user) if nested_resources.empty?

        nested_resources.each do |res, fields|
          res = if res.to_s == current_resource.class.name.downcase
            current_resource
          else
            current_resource.send(res)
          end
          update_resource res, fields, as: user
        end
      end
    end
    
    def self.included(base)
      base.extend(ClassMethods)
    end
    
    private
    
    def add_user_id_to(hash_or_user, user_hash)
      return unless hash_or_user.present? and user = user_hash[:as]
      user_class = user.class.model_name.downcase.underscore # 'user', etc.
      
      case hash_or_user
      when Hash
        hash_or_user[:"#{user_class}_identifier"] = user.id
      else
        hash_or_user.send :"#{user_class}=", user
      end
    end
    
    def update_resource(*args) # resource, (optional: fields=[]), user_hash={}
      resource = args.first
      user_hash = args.last
      return unless user = user_hash[:as]
      fields = args[1] if args.count > 2
      
      resource_name = resource.class.name.downcase
      parameters = params[resource_name]
      
      if parameters.present? and fields.present?
        # update the parameters hash with modified resources
        fields.each do |field|
        
          field_attribute = field.to_s + '_attributes' unless field[/_attributes/].present?
          handle = parameters[field_attribute]
  
          updated = Array(handle).each do |individual_resource|
            add_user_id_to(individual_resource, as: user)
          end

          params[resource_name][field_attribute] = updated
        end
      else
        add_user_id_to(resource, as: user)
      end
    end
  end
end
