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

#### `has_mixed_identifier_for`

With `modify_resource` comes the ability to associate objects using a "vague" ID - for example, to associate a `Comment` in a blog system to a post only using a slug instead of an ID.

Here's how you do that:

```ruby
class Comment < ActiveRecord::Base
  has_mixed_identifier_for :post, key: "slug"
end
```

This means you could do `Comment.new(post_identifier: "my-post-slug")` and everything would match up automatically so long as the `Post#slug` field matches "my-post-slug".

##### Mixed resource identifiers as users

In most software it's important to create items as a user - as its owner or creator. Therefore there's also functionality to attach a user to a resource using the new member's email address _before that member is even created_. Currently, this only works with Devise.

To be specific, one is able to add the following to their `Model`:

```ruby
class Comment < ActiveRecord::Base
  has_mixed_identifier_for :user
end
```

Then, if a comment is created like this:

```ruby
Comment.new(user_identifier: "asdf@example.com")
```

The user `asdf@example.com` could be created by that email instead of just not being found. You'll need to implement `invite_as_user!` on your user model, which requires `devise_invitable` to invite users.

`as_user` will be set automatically on your parent resource -- for example, the Post your are updating with a `PUT` request -- so you simply need as add the following to your comment model:

```ruby
class Comment < ActiveRecord::Base
  belongs_to :post
  delegate :as_user, to: :post
end
```

Alternatively, you could of course set `as_user=` on your `Comment`, but that kind of goes against `modify_resource`'s entire purpose :)

This works with the following options:

    has_mixed_identifier_for :user,
      key: "string" # change from `email`, the default - could be a mobile phone number, for example
      invite_options: { skip_invitation: true | false } ## if true, do not send invitation email 
      required: true | false # in your controllers, you MUST send as_user= as detailed above or an error will be thrown

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
