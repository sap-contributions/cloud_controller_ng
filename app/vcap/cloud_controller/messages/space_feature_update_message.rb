require 'messages/base_message'

module VCAP::CloudController
  class SpaceFeatureUpdateMessage < BaseMessage
    register_allowed_keys [:enabled]

    validates_with NoAdditionalKeysValidator
    validates :enabled, boolean: true
  end
end
