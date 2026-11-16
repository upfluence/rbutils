module Upfluence
  module HTTP
    module Middleware
      class MountPoint
        ENV_KEY = 'upfluence.mount'.freeze

        Mount = Struct.new(:script_name, :path_info, :endpoint)

        def initialize(app, builder)
          @app = app
          @endpoint = builder.endpoint
        end

        def call(env)
          env[ENV_KEY] = Mount.new(
            env['SCRIPT_NAME'].to_s,
            env['PATH_INFO'].to_s,
            @endpoint
          )

          @app.call(env)
        end
      end
    end
  end
end
