# Rbutils

# Description

Upfluence-utils is a utility box for ruby ​​projects. Some important abstractions are:

- Sentry error logger

- Base Api Endpoint

- Middlewares

- Mixins

## Usage

Add in your gemfile the `gem 'upfluence-utils'` and run `bundle install`

### Sentry error logger

Upfluence-utils provide the tool to notify sentry once one ruby is raised

### Base ApiEndpoint

The class APIEndpoint can be inherited from your new endpoint mapped class in you ruby project, so you can take advantage of some resources, like:

- Healthcheck endpoint
- Access token validation
- Request body and serialize json_params
- `respond_with` to easily serialize a body response
- Base errors

to use you can inherit like:
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

### Mixins

Based on the concept of [mixins](https://en.wikipedia.org/wiki/Mixin#:~:text=at%20the%20time.-,Definition,mixed%20in%20with%20other%20classes.), this classes provides some good tools, like:

- Pagination
- StrongParameters (class to validate params received/sent on endpoint)

you can use mixins from upfluence-utils like:

```ruby
    class YourClassEndpoint < AuthorizedEndpoint
      include Upfluence::Mixin::Pagination
      include Upfluence::Mixin::StrongParameters
    end
```
