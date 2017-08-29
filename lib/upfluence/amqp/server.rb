module Upfluence
  module AMQP
    class Server
      DEFAULT_OPTIONS = {
        amqp_uri: ENV['RABBITMQ_URL'] || 'amqp://localhost:5672/%2'
      }
    end
  end
end
