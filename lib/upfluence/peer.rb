require 'cgi'

module Upfluence
  class Peer
    class Version
      class SemanticVersion
        attr_reader :major, :minor, :patch, :suffix

        def initialize(major:, minor:, patch:, suffix: nil)
          @major = major
          @minor = minor
          @patch = patch
          @suffix = suffix
        end

        def to_s
          v = "v#{@major}.#{@minor}.#{@patch}"

          v += "-#{@suffix}" if @suffix
          v
        end

        class << self
          def parse(version)
            return nil unless version

            v, suffix = version.split('-', 2)

            vs = v.split('.')

            return nil unless vs.count.eql? 3

            SemanticVersion.new(
              major:  vs[0].delete_prefix('v').to_i,
              minor:  vs[1].to_i,
              patch:  vs[2].to_i,
              suffix: suffix
            )
          end
        end
      end

      class GitVersion
        attr_reader :commit, :remote, :branch

        def initialize(commit:, remote: nil, branch: nil)
          @commit = commit
          @remote = remote
          @branch = branch
        end

        def to_s
          "v0.0.0+git-#{@commit[0..6]}"
        end
      end

      DEFAULT_VERSION = 'v0.0.0-dirty'.freeze

      attr_reader :git, :semantic

      def initialize(git, semantic)
        @git = git
        @semantic = semantic
      end

      def to_s
        return @semantic.to_s if @semantic
        return @git.to_s if @git

        DEFAULT_VERSION
      end
    end

    attr_reader :environment, :authority, :instance_name, :project_name,
                :app_name

    def initialize(authority:, instance_name:, app_name:, project_name:,
                   environment:, version: nil)
      @authority = authority || 'local'
      @instance_name = instance_name ||  'unknown-server'
      @app_name = app_name || 'unknown-app'
      @project_name = project_name || 'unknown-app'
      @environment = environment || 'development'
      @version = version
    end

    def to_url
      query = {
        'app-name'         => @app_name,
        'project-name'     => @project_name,
        'git-version'      => @version.git&.commit,
        'semantic-version' => @version.semantic&.to_s
      }.compact.map { |k, v| "#{k}=#{CGI.escape(v)}" }.join('&')

      "peer://#{@environment}@#{@authority}/#{@instance_name}?#{query}"
    end

    class << self
      def from_env
        Peer.new(
          authority:     ENV['AUTHORITY'],
          instance_name: ENV['UNIT_NAME'],
          app_name:      ENV['APP_NAME'],
          project_name:  ENV['PROJECT_NAME'],
          environment:   ENV['ENV'],
          version:       Version.new(
            build_git_version,
            Version::SemanticVersion.parse(ENV['VERSION'])
          )
        )
      end

      private

      def build_git_version
        commit = ENV['GIT_COMMIT']

        return nil unless commit

        Version::GitVersion.new(
          commit: commit,
          remote: ENV['GIT_REMOTE'],
          branch: ENV['GIT_BRANCH']
        )
      end
    end
  end
end
