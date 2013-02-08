require "require_all"

$: << File.dirname(__FILE__)

require "modify_resource/version"
require "modify_resource/rails/action_controller/modify_resource"
require "modify_resource/rails/action_controller/update_as"
require "modify_resource/rails/active_model/update_permitted_attributes"
require "modify_resource/rails/active_record/mixed_identifier_for_user_resource"

module ModifyResource

  def self.included(base)
    if defined? Rails and base < ActionController::Base
      
      # Add `modify_on` and other methods to the controller
      base.send :include, ActionController::ModifyResource
      base.send :include, ActionController::UpdateAs
    end
  end
  
end
