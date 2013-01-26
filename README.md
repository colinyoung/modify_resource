# ModifyResource

## Installation

Add this line to your application's Gemfile:

    gem 'modify_resource'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install modify_resource

## Usage

#### Including

Just include `ModifyResource` in your controller, or, if you want it available in your entire application:

```ruby
# application.rb
class ApplicationController < ActionController::Base

  class << self
    include Rails.application.routes.url_helpers
  end
  
end
```

#### `redirect_to`

You can change how your successful `create`s or `update`s are handled by changing where they redirect to in the `options` hash.

Note: If you want to use the `:redirect_to` option, and you want to use Rails routes, you'll need to `include ActionController::Base` in your controller (or ApplicationController) that you also `include ModifyResource` in.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
