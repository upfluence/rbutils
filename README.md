# Upfluence_Utils

# Description

Upfluence-utils is an utility box for ruby ​​projects. Some important abstractions are:

- Sentry error logger

- Base Api Endpoint

- Middlewares

- Mixins

## Usage

Add in your gemfile the `gem 'upfluence-utils'` and run `bundle install`

### Sentry error logger

Upfluence-utils provides the tool to notify sentry when a ruby error is raised.

It is based on the 'sentry-ruby' sdk, you can check the [documentation](https://docs.sentry.io/platforms/ruby/)..

Upfluence-utils also already provides the [basic configuration](https://docs.sentry.io/platforms/ruby/configuration/options/?original_referrer=https%3A%2F%2Fwww.google.com%2F) [here](https://github.com/upfluence/upfluence_utils/blob/fd9bb88960f7dbe04dc43180489207d2739cb0ff/lib/upfluence/error_logger/sentry.rb#L17) so it works like 'plug and play' and you just have to be aware of the environment variables.

### Base ApiEndpoint

The class APIEndpoint can be inherited from your new endpoint mapped class in you ruby project, so you can take advantage of some resources, like:

- Healthcheck endpoint
- Access token validation
- Request body and serialize json_params
- `respond_with` to easily serialize a body response
- Base errors

You can inherit like:
```ruby
class YourClassEndpoint < Upfluence::Endpoint::ApiEndpoint
end
```

### Middlewares

Provide some utils for http requests, such as:

- Headers builder
- Cors
- Prometheus logger
- Base Exceptions

### Stats

A Ruby port of [upfluence/stats](https://github.com/upfluence/stats): metrics
are created from scopes, which carry a namespace and a set of tags inherited by
their children.

```ruby
scope = Upfluence::Stats.root_scope # backed by Prometheus::Client.registry

db    = scope.scope('database', service: 'user-api')
redis = db.scope('redis', cluster: 'cache-01')

redis.counter('queries_total').inc # database_redis_queries_total{service,cluster}
redis.counter_vector('errors_total', %w[kind]).with_labels(kind: 'timeout').add(2)
scope.gauge('active_connections').update(42)
scope.histogram('latency_seconds', buckets: [0.01, 0.1, 1]).record(0.12)

Upfluence::Stats::Timer.new(scope, 'op').time { work } # op_seconds
Upfluence::Stats::Instrument.new(scope, 'job').exec { work }
# job_started_total, job_total{status}, job_duration_seconds
```

Use `Upfluence::Stats::RootScope.new(collector)` to build a root scope on a
custom collector (`Collector::Prometheus.new(registry)` or
`Collector::Static.new` for specs), and `Upfluence::Stats::NOOP_SCOPE` to
disable metrics.

### Mixins

Based on the concept of [mixins](https://en.wikipedia.org/wiki/Mixin#:~:text=at%20the%20time.-,Definition,mixed%20in%20with%20other%20classes.), these classes provide some good tools, like:

- Pagination
- StrongParameters (class to validate params received/sent on endpoint)

you can use mixins from upfluence-utils like:

```ruby
    class YourClassEndpoint < AuthorizedEndpoint
      include Upfluence::Mixin::Pagination
      include Upfluence::Mixin::StrongParameters
    end
```

#### Pagination

For pagination, you can be inspired on this example:

```http
[GET] /my_entity/?per_page=1&page=1
```

```ruby
get '/' do
  respond_with_pagination(
    payload:         my_entity_paginated, # this should return the paginated model, you can use active record methods to do that
    each_serializer: MyEntity::MyEntitySerializer, # serializer related to the model
    except:          %i[field], # some entity related you want to ignore on serialization
    root:            'my_entity'
  )
end
```

#### StrongParams

For StrongParams mixin, you can be inspired like this example how to permit only some specific fields on POST request:

```ruby
def create_params
  json_params.require(:my_entity).permit(
    :entity_name,
    :entity_number
  )
end
```
