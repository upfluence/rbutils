module Upfluence
  module HTTP
    module Middleware
      class ApplicationHeaders
        def initialize(app, handler)
          @app = app
          @headers = handler ? build_headers(handler) : {}
        end

        def call(env)
          status, header, body = @app.call(env)
          [status, header.merge(@headers), body]
        end

        private

        def build_headers(handler)
          {
            'X-Upfluence-Unit-Name' => handler.getName,
            'X-Upfluence-Version'   => build_version(handler.getVersion)
          }
        end

        def build_version(thrift_version)
          v = thrift_version.semantic_version
          return "v#{v.major}.#{v.minor}.#{v.patch}" if v

          v = thrift_version.git_version
          return "v0.0.0-#{v.commit}" if v

          'undefined'
        end
      end
    end
  end
end
