require_relative 'resource_info'
require_relative 'router'

module ActionController
  
  module ModifyResource
    include ResourceInfo
    include ActionView::Helpers::TextHelper
    
    module ClassMethods
      
      # A shortcut - just add modify_on :create, :update
      # if your variable is the controller's name -- e.g. @widget in WidgetsController
      def modify_on(*actions)
        # Define in the method so that the user could override if they wanted
        options = actions.extract_options!
        actions.each do |action|
          unless method_defined?(action)
            define_method action do
              modify_resource_with action, options
            end
          end
        end
      end
    end
    
    # :nodoc:
    def self.included(base)
      base.extend(ClassMethods)
    end
        
    # Handles the usual @var = Model.find(params[:id]); @var.save
    # etc. stuff.
    def modify_resource_with(*args) # ([res=nil, ], verb=:update, options={}, args=nil)
      # Set var to resource matching controller's name if res is a symbol
      if args.first.is_a? Symbol or args.first.is_a? String
        res = instance_variable_get(:"@#{resource_name}")
      else
        res = args.shift
      end
      
      # Set up default values
      verb      = args[0] || :update
      options   = args[1] || {}
      _params   = args[2] || nil
      as_user   = nil
      
      # model_name is this res's model_name
      model_name = res.class.model_name.underscore.downcase
      
      # Grab params if not set
      _params ||= params[model_name]
      
      # We may need the current user instance
      options[:as_current] ||= options[:as_user] # Backwards compat
      
      if options[:as_current] and res.respond_to?(:as_user)
        res.as_user = self.send "current_#{options[:as_current]}"
      end
      
      # Actually perform update, or create, destroy, etc.
      modified = case verb
        when :update
          res.update_permitted_attributes(_params)
        when :create
          res.deep_attributes = _params
          res.persisted?
        else
          res.method(verb).arity == 0 ? res.send(verb) : res.send(verb, _params)
        end
        
      # the resource was updated
      instance_variable_set :"@#{resource_name}", res
      
      raise 'As_user MUST be unset on ALL items.' if res.valid? and res.as_user.present?
      
      # We're updating a nested resource, so we need to set its parent for it
      update_resource_parent(res) unless parent_for(res).present?
      
      # Actually save or create.
      if modified
        
        unless request.xhr?
          
          options[:redirect_with_resources] ||= [ :self ]
          after = params[:after]

          # Collect options for `url_for()`
          url_options = options[:url_options] || {}
          path_options = options[:path_options] || {}

          # Determine the success path.
          unless (path = options[:redirect_to]).blank?
            router = Router.new
            collected_resources = collect_resources_for(res, options[:redirect_with_resources])
            # `url_for()` options may be dynamic.
            path_options.each do |k,v|
              url_options[k] = v.call(*collected_resources) if v.is_a? Proc
              collected_resources.pop if k == :anchor # Remove last item, because we're using it in the anchor
            end
            success_path = if collected_resources.blank?
              router.send path, url_options
            else
              router.send path, *collected_resources, url_options
            end
          end
          success_path ||= resource_path_with_base(:production, res)
          
          msg = options[:success].try(:call, res)
          
          if msg.blank?
            
            msg = "#{action_name.capitalize.gsub(/e$/,'')}ed "
            
            if after.present? and after.pluralize == after
              # Redirect to the plural (index) page
              model_name = params[:after]
              msg << model_name.pluralize
              success_path << '/' + after
            else
              # Redirect to the show page for the resource.
              # Flash is like 'Widget 2 has been updated'.
              name = String.new.tap do |s|
                break s = res.title if res.respond_to? :title
                break s = res.name if res.respond_to? :name
                s = res.id
              end
              msg << "#{model_name.humanize.downcase} '#{truncate(name, length: 20)}'"
            end
          end
          
          flash[:notice] = msg
          redirect_to success_path
        else
          render json: res
        end
      else
        messages = res.errors.messages
        unless request.xhr?
          flash[:error] = messages
          begin
            render :edit
          rescue
            # They didn't respond to that action
            if res.persisted?
              render :show
            else
              render :new
            end
          end
        else
          render json: {errors: messages}, status: :unprocessable_entity
        end
      end
    end
    
    private
    
    # :nodoc:
    def resource_path_with_base(base, res)
      components, resources = path_components_for(res, base).try(:compact)
      
      return url_for unless components.present?
      
      unless components.nil? || components.empty?
        path = components.join('_') + '_path'
        send(path, *resources)
      else
        :"#{base.to_s.pluralize}"
      end
    end
    
    # :nodoc: Climbs up the resource's parent associations to generate a rails route
    def path_components_for(res, base, components=[], resources=[])
      return nil unless res.present?
      
      component = component_for(res)
      
      # Redirect to the index if the res was just deleted
      component = component.pluralize unless res.persisted?
      
      components.unshift component
      resources.unshift res if res.persisted?
      
      unless component.to_s == base.to_s
        path_components_for(parent_for(res), base, components, resources)
      else
        [components, resources]
      end
    end
    
    # :nodoc: gets path component for a resource
    def component_for(res)
      res.class.model_name.downcase
    end
    
    # :nodoc: gets a nested resource's parent
    def parent_for(res)      
      parents = possible_parents_for(res)
      return nil unless parents.count == 1
      
      component = component_for(res)
      parent_component = parents[0].sub('_id', '')
      res.send(parent_component)
    end 
    
    # :nodoc: gets possible parents based on attributes ending in '_id'
    def possible_parents_for(res)      
      Array.new.tap do |possibilities|
        res.attributes.keys.each do |field|
          next unless field[/_id$/]
          cleaned = field.sub '_id', ''
          # Fields that end in _id but do not point to a constant are ignored.
          possibilities << cleaned if Object.const_defined? cleaned.classify
        end
      end
    end
    
    # :nodoc: Adds the resource to its parent
    def update_resource_parent(res)
      parents = possible_parents_for(res)
      return if parents.empty? or parents.count > 1
      
      if parents.count > 1
        raise "Can't guess parent, multiple options for resource.\n#{res.inspect}\n#{parents.inspect}"
      end
      
      parent_class = parents.first.classify.constantize
      parent_name = parent_class.model_name.downcase
      parent_param = parent_name + '_id'
      return unless params[parent_param].present?
      
      begin
        parent = parent_class.find(params[parent_param])
      rescue ActiveRecord::RecordNotFound
        return # Parent id wasn't given in parameters. Let's let the model validations handle this.
      end
      
      instance_variable_set :"@#{parent_name}", parent
      
      child_name = res.class.model_name.downcase.pluralize
      child_name = child_name.singularize if !parent.respond_to?(child_name)
      
      association = parent.send(child_name)
      association << res
    end
    
    # Converts a list of symbols into the items necessary to compose redirection URLS
    def collect_resources_for res, arr
      arr.collect do |member|
        member == :self ? res : res.__send__(member)
      end
    end
  end
end