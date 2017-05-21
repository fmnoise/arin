# Arin

Arin - ActiveRecord integrity checking tool

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'arin', github: 'fmnoise/arin'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install arin

## Usage

Consider the example: Order belongs to User which doesn't exist anymore.

In order to find models of certain class which points to non-existant entities we need to pass class contant to constructor
```ruby
Arin::Check.new(Order).issues

# callable object style
Arin::Check.(Order)
```
Multiple classes should be passed as array
```ruby
Arin::Check.new([Payment, Order]).issues

# callable object style
Arin::Check.([Payment, Order])
```
Omit parameters to check all loaded models
```ruby
Rails.application.eager_load!
Arin::Check.new.issues

# callable object style
Arin::Check.()
```

Working with found issues collection which is simple array of `Arin::Issue` instances
```ruby
issue = Arin::Check.().first
=> #<Arin::Issue:0x007f9fe2823af0
 @class_name="Order",
 @id=6789,
 @relation_class="User",
 @relation_id=4567>

issue.class_name
=> "Order"

issue.id
=> 6789

issue.relation_class
=> "User"

issue.relation_id
=> 4567

issue.object
=> #<Order:0x007f9fdfbd9af8
  id: 6789,
  user_id: 4567
  created_at: Tue, 15 Dec 2016 01:45:37 UTC +00:00,
  updated_at: Sun, 20 Jun 2017 20:06:36 UTC +00:00>
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

*The main idea behind Arin development is to stay as small and unopinionated as possible*
Bug reports and pull requests are welcome on GitHub at https://github.com/fmnoise/arin.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
