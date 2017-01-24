require 'redis'

module Upfluence
  module Endpoint
    class WebsiteEndpoint < Sinatra::Base
      DEFAULT_IDENTIFIER = 'current'
      SEPARATOR = ':'

      get '/*' do
        bootstrap_index(params[:index_key])
      end

      private

      def bootstrap_index(index_key)
        version = if index_key && redis.exists(key(index_key))
                    key(index_key)
                  else
                    redis.get(key(DEFAULT_IDENTIFIER))
                  end
        redis.get(version)
      end

      def key(identifier)
        [ENV['FRONTEND_KEY'], identifier].compact.join(SEPARATOR)
      end

      def redis
        @redis ||= Redis.new(url: ENV['REDIS_URL'])
      end
    end
  end
end

