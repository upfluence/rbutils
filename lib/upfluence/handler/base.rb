require 'base/base_service/base_service'
require 'base/version/version_types'
require 'base/version'

module Upfluence
  module Handler
    class Base
      def initialize(modules = [])
        @alive_since = Time.now.to_i
        @modules = modules.reduce({ 'base' => ::Base::VERSION }) do |acc, cur|
          acc.merge cur.name.downcase => cur::VERSION
        end
      end

      def getVersion
        semantic_version = if ENV['SEMVER_VERSION']
          major, minor, patch = ENV['SEMVER_VERSION'].split('.')
          ::Base::Version::SemanticVersion.new(
            major: major[1..-1].to_i,
            minor: minor.to_i,
            patch: patch.to_i
          )
        end

        git_version = if ENV['GIT_COMMIT']
          ::Base::Version::GitVersion.new(
            commit: ENV['GIT_COMMIT'],
            branch: ENV['GIT_BRANCH'],
            remote: ENV['GIT_REMOTE']
          )
        end

        ::Base::Version::Version.new(
          semantic_version: semantic_version,
          git_version: git_version
        )
      end

      def getName
        ENV['UNIT_NAME'] || 'default'
      end

      def getStatus
        ::Base::Base_service::Status::ALIVE
      end

      def aliveSince
        @alive_since
      end

      def getInterfaceVersions
        @modules
      end
    end
  end
end
