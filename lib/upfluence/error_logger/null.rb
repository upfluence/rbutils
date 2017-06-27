module Upfluence
  module ErrorLogger
    class Null
      def notify(error, _method, *_args)
        Upfluence.logger.error(error.inspect)
      end
    end
  end
end
