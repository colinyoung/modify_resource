module ActionController
  module ModifyResource
    module ResourceInfo
      
      def resource_name
        controller_name[/(\w+)$/].singularize
      end
    
      def model_class
        resource_name.capitalize.constantize
      end
    
      def resource
        returning res = nil do
          res = instance_variable_get("@#{resource_name}")
          begin
            res ||= model_class.find(params[:id])
          rescue; end
        end
      end
      
    end
  end
end