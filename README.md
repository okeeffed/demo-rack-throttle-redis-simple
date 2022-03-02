# README

## Steps

```s
# Create project
$ rails new demo-rack-throttle-redis-simple
$ cd demo-rack-throttle-redis-simple

# Install the required gem
$ bundler add rack-throttle

# Scaffold a route to test against
$ bin/rails g controller hello index
```

Inside of `config/application.rb`:

```rb
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

    # Setting rules and configuration for our `rack-throttle` middleware.
    rules = [
      { method: 'POST', limit: 5 },
      { method: 'GET', limit: 10 },
      { method: 'GET', path: '/hello', limit: 1 }
    ]
    default = 10

    config.middleware.use Rack::Throttle::Rules, cache: Redis.new, rules: rules, default: default
  end
end
```

Update `config/routes.rb`:

```rb
Rails.application.routes.draw do
  resources :hello, only: [:index]
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"
end
```

Update `app/controllers/hello_controller.rb`:

```rb
class HelloController < ApplicationController
  def index
    render json: { message: 'Hello, World!' }
  end
end
```

Run `rails s`.

## Seeing what happens

Using [`ab`](https://en.wikipedia.org/wiki/ApacheBench) for testing:

```s
$ ab -n 6 http://localhost:3000/hello
This is ApacheBench, Version 2.3 <$Revision: 1879490 $>
Copyright 1996 Adam Twiss, Zeus Technology Ltd, http://www.zeustech.net/
Licensed to The Apache Software Foundation, http://www.apache.org/

Benchmarking localhost (be patient).....done


Server Software:
Server Hostname:        localhost
Server Port:            3000

Document Path:          /hello
Document Length:        27 bytes

Concurrency Level:      1
Time taken for tests:   0.080 seconds
Complete requests:      6
Failed requests:        5
   (Connect: 0, Receive: 0, Length: 5, Exceptions: 0)
Non-2xx responses:      5
Total transferred:      1698 bytes
HTML transferred:       122 bytes
Requests per second:    74.61 [#/sec] (mean)
Time per request:       13.403 [ms] (mean)
Time per request:       13.403 [ms] (mean, across all concurrent requests)
Transfer rate:          20.62 [Kbytes/sec] received

Connection Times (ms)
              min  mean[+/-sd] median   max
Connect:        0    0   0.2      0       1
Processing:    10   13   4.3     11      21
Waiting:       10   13   4.3     11      21
Total:         10   13   4.4     11      22

Percentage of the requests served within a certain time (ms)
  50%     11
  66%     11
  75%     15
  80%     15
  90%     22
  95%     22
  98%     22
  99%     22
 100%     22 (longest request)
```

On the Rails server console we get:

```s
Started GET "/hello" for ::1 at 2022-03-02 16:56:06 +1000
Processing by HelloController#index as */*
Completed 200 OK in 1ms (Views: 0.2ms | ActiveRecord: 0.0ms | Allocations: 114)


Started GET "/hello" for ::1 at 2022-03-02 16:56:06 +1000
Started GET "/hello" for ::1 at 2022-03-02 16:56:06 +1000
Started GET "/hello" for ::1 at 2022-03-02 16:56:06 +1000
Started GET "/hello" for ::1 at 2022-03-02 16:56:06 +1000
Started GET "/hello" for ::1 at 2022-03-02 16:56:06 +1000
```

The last 5 do not complete.

Running and observing `redis-cli monitor`:

```s
$ redis-cli monitor
1646204030.703184 [0 127.0.0.1:64523] "get" "throttle:::1_GET_/hello:2022-03-02T16:53:50"
1646204030.703369 [0 127.0.0.1:64523] "set" "throttle:::1_GET_/hello:2022-03-02T16:53:50" "1"
1646204030.715999 [0 127.0.0.1:64523] "get" "throttle:::1_GET_/hello:2022-03-02T16:53:50"
1646204030.716196 [0 127.0.0.1:64523] "set" "throttle:::1_GET_/hello:2022-03-02T16:53:50" "2"
1646204030.726116 [0 127.0.0.1:64523] "get" "throttle:::1_GET_/hello:2022-03-02T16:53:50"
1646204030.726411 [0 127.0.0.1:64523] "set" "throttle:::1_GET_/hello:2022-03-02T16:53:50" "3"
1646204030.743322 [0 127.0.0.1:64523] "get" "throttle:::1_GET_/hello:2022-03-02T16:53:50"
1646204030.745936 [0 127.0.0.1:64523] "set" "throttle:::1_GET_/hello:2022-03-02T16:53:50" "4"
1646204030.760111 [0 127.0.0.1:64523] "get" "throttle:::1_GET_/hello:2022-03-02T16:53:50"
1646204030.760280 [0 127.0.0.1:64523] "set" "throttle:::1_GET_/hello:2022-03-02T16:53:50" "5"
1646204030.773758 [0 127.0.0.1:64523] "get" "throttle:::1_GET_/hello:2022-03-02T16:53:50"
1646204030.774029 [0 127.0.0.1:64523] "set" "throttle:::1_GET_/hello:2022-03-02T16:53:50" "6"
```

If we again run this with [`httpie`](https://httpie.io/cli) to get more info.

```s
# First successfuly request
$ http GET localhost:3000/hello
HTTP/1.1 200 OK
Cache-Control: max-age=0, private, must-revalidate
Content-Type: application/json; charset=utf-8
ETag: W/"8811a6f55cb434d10921bccf7108016d"
Referrer-Policy: strict-origin-when-cross-origin
Server-Timing: start_processing.action_controller;dur=0.152099609375, process_action.action_controller;dur=0.951904296875
Transfer-Encoding: chunked
Vary: Accept
X-Content-Type-Options: nosniff
X-Download-Options: noopen
X-Frame-Options: SAMEORIGIN
X-Permitted-Cross-Domain-Policies: none
X-Request-Id: 63a86723-bd98-4f4d-a8fc-86da84632c47
X-Runtime: 0.013456
X-XSS-Protection: 0

{
    "message": "Hello, World!"
}

# Second, rate-limited run within 1 second of the last
$ http GET localhost:3000/hello
HTTP/1.1 403 Forbidden
Cache-Control: no-cache
Content-Type: text/plain; charset=utf-8
Retry-After: 3600
Server-Timing:
Transfer-Encoding: chunked
X-Request-Id: 059ee3bd-4aa4-4578-a290-42c981711251
X-Runtime: 0.006463

Rate Limit Exceeded
```

We get a 403 forbidden on rate limited results.

## Resources

- [rack-throttle](https://github.com/dryruby/rack-throttle)
