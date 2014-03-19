module MixedIdentifierForUserResource    
  def has_mixed_identifier_for(user_resource, options={})

    options.reverse_merge! required: false
    
    user_resource = user_resource.to_s
    
    self.send :attr_accessible, :"#{user_resource}_identifier"
    
    instance_eval <<-END
      validate :"#{user_resource}_identifier", presence: true
    END
  
    class_eval <<-END
      def #{user_resource}_identifier=(identifier)
        if identifier.is_a? Fixnum or identifier.numeric? or identifier.parameter_id?
          self.#{user_resource} = #{user_resource.classify}.find(identifier)
        else
          # Try to uncover the as_user of either this resource or the parent
          self.#{user_resource} = #{user_resource.classify}.find_or_initialize_by_email(identifier)
        end
      end
      
      def #{user_resource}_identifier
        resource = self.#{user_resource}
        resource.try(:id) || resource.try(:email) || resource.try(:email_address)
      end
      
      def mass_assignment_authorizer(role)
        super(role) << "#{user_resource}_identifier"
      end
      
      # Before saving, build the user resource on the current model
      before_validation do
        if #{user_resource}.nil?
          if options[:required]
            self.errors.add "#{user_resource}".to_sym, "required for " + self.class.model_name + self.attributes.inspect
          else
            return
          end
        end
        if #{user_resource}.present? and #{user_resource}.new_record?
          unless #{user_resource}.respond_to? :invite_as_user!
            self.errors.add "#{user_resource}".to_sym, 'must define #invite_as_user! if you include MixedIdentifierForUserResource in it.'
          end
          self.errors.add "#{user_resource}".to_sym, 'cannot be built without a user present' unless @as_user.present?
          new_member = #{user_resource}.invite_as_user! @as_user
          self.#{user_resource} = new_member
        else
          self.#{user_resource}_id = #{user_resource}_id
        end
      end
    END
    
  end
end

class String
  
  # Is the string something like '234234234-Joe-Test'? This is used in params.
  def parameter_id?
    self[/^[0-9]+\-[\D]+/].present?
  end
end

ActiveRecord::Base.extend(MixedIdentifierForUserResource)