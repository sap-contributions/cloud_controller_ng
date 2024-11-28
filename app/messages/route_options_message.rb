require 'messages/metadata_base_message'

module VCAP::CloudController
  class RouteOptionsMessage < BaseMessage
    VALID_MANIFEST_ROUTE_OPTIONS = %i[loadbalancing-algorithm].freeze
    VALID_ROUTE_OPTIONS = %i[loadbalancing_algorithm].freeze
    VALID_LOADBALANCING_ALGORITHMS = %w[round-robin least-connections].freeze

    register_allowed_keys VALID_ROUTE_OPTIONS
    validates_with NoAdditionalKeysValidator
    validates :loadbalancing_algorithm,
              inclusion: { in: VALID_LOADBALANCING_ALGORITHMS, message: "'%<value>s' is not a supported load-balancing algorithm" },
              presence: true,
              allow_nil: true
  end
end
