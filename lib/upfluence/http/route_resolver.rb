require 'rack/request'
require 'upfluence/http/middleware/mount_point'

module Upfluence
  module HTTP
    module RouteResolver
      UNEXPECTED_ROUTE = 'unexpected-route'.freeze

      class << self
        def resolve(env, code = nil)
          mount = env[Middleware::MountPoint::ENV_KEY]
          not_found = code.to_s.eql?('404')

          resolve_sinatra(env, mount) || resolve_rails(env) ||
            resolve_mount(env, mount, not_found) ||
            resolve_default(env, not_found)
        end

        private

        def resolve_rails(env)
          params = env['action_dispatch.request.parameters']
          return nil if params.nil?

          "#{params['controller']}##{params['action']}"
        end

        def resolve_sinatra(env, mount)
          route = env['sinatra.route']
          return nil if route.nil? || route.strip == ''

          "#{mount&.script_name}#{route.split(' ', 2).last}"
        end

        # Used when the request never reached the router of the mounted app
        # (e.g. throttled or failed in a middleware), so the route has to be
        # resolved statically from the mount point.
        def resolve_mount(env, mount, not_found)
          return nil if mount.nil? || not_found

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

        def resolve_default(env, not_found)
          return UNEXPECTED_ROUTE if not_found

          Rack::Request.new(env).path.gsub(%r{/\d+(/|$)}, '/:id\\1')
        end
      end
    end
  end
end
