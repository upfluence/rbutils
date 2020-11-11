module Upfluence
  class Peer
    attr_reader :environment, :authority, :instance_name, :project_name,
                :app_name

    def initialize(opts = {})
      @authority = opts[:authority] || 'local'
      @instance_name = opts[:instance_name] || 'unknown-server'
      @app_name = opts[:app_name] || 'unknown-name'
      @project_name = opts[:project_name] || 'unknown-app'
      @environment = opts[:environment] || 'development'
    end

    def to_url
      "peer://#{@environment}@#{@authority}/#{@instance_name}"
    end

    class << self
      def from_env
        Peer.new(
          authority:     ENV['AUTHORITY'],
          instance_name: ENV['INSTANCE_NAME'],
          app_name:      ENV['APP_NAME'],
          project_name:  ENV['PROJECT_NAME'],
          environment:   ENV['ENV']
        )
      end
    end
  end
end
