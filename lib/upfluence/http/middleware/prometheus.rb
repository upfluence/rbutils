require 'upfluence/environment'
require 'upfluence/http/route_resolver'
require 'upfluence/stats'

module Upfluence
  module HTTP
    module Middleware
      class Prometheus
        LABELS = %i[path method].freeze

        def initialize(app, scope = Upfluence::Stats.root_scope)
          scope = scope.scope('uhttp_handler', env: Upfluence.env.to_s)

          @request_total_count = scope.counter_vector(
            'requests_total',
            LABELS + %i[status],
            docstring: 'Histogram of processed items'
          )

          @request_histogram = scope.histogram_vector(
            'requests_duration_second',
            LABELS,
            docstring: 'Histogram of processing time'
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
          path = RouteResolver.resolve(env, code)
          method = env['REQUEST_METHOD'].downcase

          @request_total_count.with_labels(path: path, method: method, status: code).inc
          @request_histogram.with_labels(path: path, method: method).record(duration)
        end
      end
    end
  end
end
