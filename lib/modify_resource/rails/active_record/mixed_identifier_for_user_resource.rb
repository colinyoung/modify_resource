module MixedIdentifierForUserResource    
  def has_mixed_identifier_for(user_resource, options={})
    
    user_resource = user_resource.to_s
    
    self.send :attr_accessible, :"#{user_resource}_identifier"
    
    instance_eval <<-END
      validate :"#{user_resource}_identifier", presence: true
    END
  
    class_eval <<-END
      def #{user_resource}_identifier=(identifier)
        if identifier.is_a? Fixnum or identifier.numeric? or identifier.parameter_id?
          self.#{user_resource}_id = identifier
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
      
      before_validation do
        if #{user_resource}.present? and #{user_resource}.new_record? and #{user_resource}.respond_to? :invite!
          #{user_resource}.invite! @as_user
          self.#{user_resource}_id = #{user_resource}.id
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