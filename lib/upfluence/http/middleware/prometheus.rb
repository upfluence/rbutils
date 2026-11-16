require 'prometheus/client'
require 'upfluence/environment'
require 'upfluence/http/middleware/mount_point'

module Upfluence
  module HTTP
    module Middleware
      class Prometheus
        LABELS = %i[path method env].freeze

        def initialize(app, registry = ::Prometheus::Client.registry)
          @registry = registry

          @request_total_count = @registry.get(
            :uhttp_handler_requests_total
          ) || @registry.counter(
            :uhttp_handler_requests_total,
            docstring: 'Histogram of processed items',
            labels:    LABELS + %i[status]
          )

          @request_histogram = @registry.get(
            :uhttp_handler_requests_duration_second
          ) || @registry.histogram(
            :uhttp_handler_requests_duration_second,
            docstring: 'Histogram of processing time',
            labels:    LABELS
          )

          @app = app
        end

        def call(env)
          trace(env) { @app.call(env) }
        end

        private

        def trace(env)
          start = Time.now
          yield.tap do |response|
            duration = [(Time.now - start).to_f, 0.0].max
            record(env, response.first.to_s, duration)
          end
        end

        def record(env, code, duration)
          path = parse_route(env, code)

          @request_total_count.increment(
            labels: {
              path:   path,
              method: env['REQUEST_METHOD'].downcase,
              status: code,
              env:    Upfluence.env.to_s
            }
          )

          @request_histogram.observe(
            duration,
            labels: {
              path:   path,
              method: env['REQUEST_METHOD'].downcase,
              env:    Upfluence.env.to_s
            }
          )
        end

        def parse_route(env, code)
          mount = env[MountPoint::ENV_KEY]

          parse_route_sinatra(env, mount) || parse_route_rails(env) ||
            parse_route_mount(env, mount, code) ||
            parse_route_default(env, code)
        end

        def parse_route_rails(env)
          params = env['action_dispatch.request.parameters']
          return nil if params.nil?

          "#{params['controller']}##{params['action']}"
        end

        def parse_route_sinatra(env, mount)
          route = env['sinatra.route']
          return nil if route.nil? || route.strip == ''

          "#{mount&.script_name}#{route.split(' ', 2).last}"
        end

        # Used when the request never reached the router of the mounted app
        # (e.g. throttled or failed in a middleware), so the route has to be
        # resolved statically from the mount point.
        def parse_route_mount(env, mount, code)
          return nil if mount.nil? || code.to_s.eql?('404')

          route = resolve_sinatra_route(
            mount.endpoint,
            env['REQUEST_METHOD'],
            mount.path_info
          )

          route ||= '/*' unless ['', '/'].include?(mount.path_info)

          "#{mount.script_name}#{route}"
        end

        def resolve_sinatra_route(endpoint, verb, path)
          return nil unless defined?(::Sinatra::Base)

          klass = endpoint.respond_to?(:settings) ? endpoint.settings : endpoint
          path = '/' if path.empty?

          while klass.is_a?(Class) && klass <= ::Sinatra::Base
            (klass.routes[verb] || []).each do |pattern, _conditions, _block|
              return pattern.to_s if pattern.params(path)
            end

            klass = klass.superclass
          end

          nil
        rescue StandardError
          nil
        end

        def parse_route_default(env, code)
          return 'unexpected-route' if code.to_s.eql? '404'

          Rack::Request.new(env).path.gsub(%r{/\d+(/|$)}, '/:id\\1')
        end
      end
    end
  end
end
