require 'cloud_controller/diego/lifecycles/buildpack_info'
require 'cloud_controller/diego/docker/docker_uri_converter'
require 'fetchers/buildpack_lifecycle_fetcher'

module VCAP::CloudController
  class CNBLifecycle
    attr_reader :staging_message, :buildpack_infos

    def initialize(package, staging_message)
      @staging_message = staging_message
      @package = package

      db_result = BuildpackLifecycleFetcher.fetch(formatted_buildpacks, staging_stack)
      @buildpack_infos = db_result[:buildpack_infos]
    end

    def type
      Lifecycles::CNB
    end

    def create_lifecycle_data_model(build)
      VCAP::CloudController::CNBLifecycleDataModel.create(
        buildpacks: Array(formatted_buildpacks),
        stack: staging_stack,
        build: build
      )
    end

    def staging_environment_variables
      {}
    end

    def valid?
      true
    end

    def errors
      []
    end

    def staging_stack
      requested_stack || app_stack || VCAP::CloudController::Stack.default.name
    end

    private

    def formatted_buildpacks
      #FIXME: Do we need this? We should add a test!
      converter = VCAP::CloudController::DockerURIConverter.new

      buildpacks_to_use.map do |buildpack|
        if buildpack.include? '://'
          buildpack
        else
          converter.convert(buildpack).sub("#", ":")
        end
      end
    end

    def buildpacks_to_use
      staging_message.buildpack_data.buildpacks || @package.app.lifecycle_data.buildpacks
    end

    def requested_stack
      @staging_message.buildpack_data.stack
    end

    def app_stack
      @package.app.buildpack_lifecycle_data.try(:stack)
    end
  end
end
