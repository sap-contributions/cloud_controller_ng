module VCAP::CloudController
  class AppCNBLifecycle
    def initialize(message)
      @message = message
    end

    def create_lifecycle_data_model(_); end

    def update_lifecycle_data_model(_); end

    def valid?
      true
    end

    def errors
      []
    end

    def type
      Lifecycles::CNB
    end
  end
end
