require "require_all"

$: << File.dirname(__FILE__)

require "modify_resource/version"
require "modify_resource/rails/action_controller/modify_resource"
require "modify_resource/rails/active_model/update_permitted_attributes"

module ModifyResource

  def self.included(base)
    if defined? Rails and base < ActionController::Base
      
      # Add `modify_on` and other methods to the controller
      base.send :include, ActionController::ModifyResource
    end
  end
  
end
