require_relative 'boot'

require 'rails/all'
require 'rack/throttle'
require 'redis'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module DemoRackThrottleRedisSimple
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Set this off so we can ping the endpoint
    config.action_controller.default_protect_from_forgery = false if ENV['RAILS_ENV'] == 'development'

    rules = [
      { method: 'POST', limit: 5 },
      { method: 'GET', limit: 10 },
      { method: 'GET', path: '/hello', limit: 1 }
    ]
    default = 10

    config.middleware.use Rack::Throttle::Rules, cache: Redis.new, rules: rules, default: default, key_prefix: :throttle
  end
end
