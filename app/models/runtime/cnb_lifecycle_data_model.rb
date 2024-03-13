require 'cloud_controller/diego/lifecycles/lifecycles'

module VCAP::CloudController
  class CNBLifecycleDataModel < Sequel::Model(:cnb_lifecycle_data)
    #include Serializer
    LIFECYCLE_TYPE = Lifecycles::CNB

    many_to_one :droplet,
                class: '::VCAP::CloudController::DropletModel',
                key: :droplet_guid,
                primary_key: :guid,
                without_guid_generation: true

    many_to_one :build,
                class: '::VCAP::CloudController::BuildModel',
                key: :build_guid,
                primary_key: :guid,
                without_guid_generation: true

    many_to_one :app,
                class: '::VCAP::CloudController::AppModel',
                key: :app_guid,
                primary_key: :guid,
                without_guid_generation: true

    def buildpacks
      nil
    end

    def buildpacks=(new_buildpacks)
    end

    def stack
      nil
    end

    def stack=(new_stack)
    end


    def valid?
      true
    end
  end
end
