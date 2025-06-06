require 'logger'

module Upfluence
  class Logger < Logger
    class Formatter < Logger::Formatter
      TIME_FORMAT = '%y%m%d %H:%M:%S'.freeze
      LOG_FORMAT = "[%s %s %s] %s\n".freeze

      def initialize(extra = 0)
        @extra = extra
      end

      def call(severity, tstamp, _progname, msg)
        LOG_FORMAT % [
          severity[0], formatted_time(tstamp), formatted_caller,
          message_to_str(msg)
        ]
      end

      def message_to_str(msg)
        msg.is_a?(String) ? msg : msg.inspect
      end

      def formatted_time(timestamp)
        timestamp.strftime(TIME_FORMAT)
      end

      def formatted_caller
        caller[4 + @extra].gsub!(/(^.+\/)?(.*):(.*):in (`|').*'/, '\\2:\\3')
      end
    end

    def logger_level(level)
      {
        'info' => Logger::INFO,
        'warn' => Logger::WARN,
        'debug' => Logger::DEBUG,
        'error' => Logger::ERROR,
        'fatal' => Logger::FATAL
      }[level] || Logger::INFO
    end

    def initialize(level = (ENV['LOGGER_LEVEL'] || '').downcase, caller_depth = 0)
      $stdout.sync = true

      super(
        $stdout,
        level:     logger_level(level),
        formatter: Formatter.new(caller_depth)
      )
    end
  end

  class << self
    def logger
      @logger ||= Logger.new
    end
  end
end
