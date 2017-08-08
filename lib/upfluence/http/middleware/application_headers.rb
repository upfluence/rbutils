module Upfluence
  module HTTP
    module Middleware
      class ApplicationHeaders
        def initialize(app, handler)
          @app = app
          @headers = {
            "X-Upfluence-Unit-Name" => handler.getName,
            "X-Upfluence-Version" => build_version(handler.getVersion)
          }
        end

        def call(env)
          status, header, body = @app.call(env)
          [status, header.merge(@headers), body]
        end

        private

        def build_version(thrift_version)
          if v = thrift_version.semantic_version
            return "v#{v.major}.#{v.minor}.#{v.patch}"
          end

          if v = thrift_version.git_version
            return "v0.0.0-#{v.commit}"
          end

          'undefined'
        end
      end
    end
  end
end
