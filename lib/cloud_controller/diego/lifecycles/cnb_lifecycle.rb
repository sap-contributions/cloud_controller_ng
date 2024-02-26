module VCAP::CloudController
  class CNBLifecycle
    attr_reader :staging_message

    def initialize(package, staging_message)
      @staging_message = staging_message
      @package = package
    end

    def type
      Lifecycles::CNB
    end

    def create_lifecycle_data_model(_); end

    def staging_environment_variables
      {}
    end

    def valid?
      true
    end

    def errors
      []
    end

    def stack
      VCAP::CloudController::Stack.default.name
    end

    def staging_stack
      VCAP::CloudController::Stack.default.name
    end
  end
end
