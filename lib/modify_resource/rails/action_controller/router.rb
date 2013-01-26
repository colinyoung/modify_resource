module ActionController
  module ModifyResource
    class Router
      
      def initialize
        self.class.send :include, Rails.application.routes.url_helpers
      end
      
    end
  end
end