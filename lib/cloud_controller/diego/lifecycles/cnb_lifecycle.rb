module VCAP::CloudController
  class CNBLifecycle
    attr_reader :staging_message, :buildpack_infos

    def initialize(package, staging_message)
      @staging_message = staging_message
      @package = package
    end

    def type
      Lifecycles::CNB
    end

    def create_lifecycle_data_model(build)
      VCAP::CloudController::CNBLifecycleDataModel.create(
        buildpacks: Array(buildpacks_to_use),
        stack: staging_stack,
        build: build
      )
    end

    def staging_environment_variables
      {}
    end

    def staging_stack
      requested_stack || app_stack || VCAP::CloudController::Stack.default.name
    end

    private

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
