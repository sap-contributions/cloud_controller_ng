require 'active_model'

module VCAP::CloudController
  class CNBLifecycleDataValidator
    include ActiveModel::Model

    attr_accessor :buildpacks

    validate :buildpacks_are_uris

    def buildpacks_are_uris
      errors.add(:buildpack, 'invalid')
    end
  end
end
