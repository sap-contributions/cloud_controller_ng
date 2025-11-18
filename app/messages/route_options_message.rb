require 'messages/metadata_base_message'

module VCAP::CloudController
  class RouteOptionsMessage < BaseMessage
    VALID_MANIFEST_ROUTE_OPTIONS = %i[loadbalancing hash_header hash_balance].freeze
    VALID_ROUTE_OPTIONS = %i[loadbalancing hash_header hash_balance].freeze
    VALID_LOADBALANCING_ALGORITHMS = %w[round-robin least-connection hash].freeze

    register_allowed_keys VALID_ROUTE_OPTIONS
    validates_with NoAdditionalKeysValidator
    validates :loadbalancing,
              inclusion: { in: VALID_LOADBALANCING_ALGORITHMS, message: "must be one of '#{RouteOptionsMessage::VALID_LOADBALANCING_ALGORITHMS.join(', ')}' if present" },
              presence: true,
              allow_nil: true

    validates :hash_header,
              string: true,
              allow_nil: true,
              format: { with: /\A[!#$%&'*+\-.^_`|~0-9a-zA-Z]+\z/, message: 'must be a valid HTTP header name' }

    validates :hash_balance,
              allow_nil: true

    validate :hash_header_required_for_hash_loadbalancing
    validate :hash_balance_must_be_zero_or_greater_than_one

    private

    def hash_header_required_for_hash_loadbalancing
      return unless loadbalancing == 'hash'
      return if hash_header.present?

      errors.add(:hash_header, 'is required when loadbalancing is set to hash')
    end

    def hash_balance_must_be_zero_or_greater_than_one
      return if hash_balance.nil?
      return if hash_balance.is_a?(Numeric) && (hash_balance == 0.0 || hash_balance >= 1.0)

      errors.add(:hash_balance, 'must be 0.0 or a number greater than or equal to 1.0')
    end

  end
end
