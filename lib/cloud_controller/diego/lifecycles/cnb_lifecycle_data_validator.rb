require 'active_model'

module VCAP::CloudController
  class CNBLifecycleDataValidator
    include ActiveModel::Model

    attr_accessor :buildpacks

    validate :buildpacks_are_uris


    def buildpacks_are_uris
    end
  end
end
