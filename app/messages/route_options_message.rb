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

    validate :hash_header_required_when_hash
    validate :hash_header_not_allowed_when_not_hash
    validate :hash_balance_validation

    attr_accessor :hash_header
    attr_reader :hash_balance_raw, :hash_balance

    def hash_balance=(value)
      @hash_balance_raw = value
      @hash_balance = convert_to_float(value) unless value.nil?
    rescue ArgumentError => e
      @hash_balance_conversion_error = e.message
    end

    private

    def convert_to_float(value)
      return nil if value.nil?
      return value if value.is_a?(Float)
      return value.to_f if value.is_a?(Integer)

      # Handle string input from CLI
      raise ArgumentError, 'hash_balance must be a number' unless value.is_a?(String)
      raise ArgumentError, 'hash_balance must be a valid number' if value.strip.empty?

      Float(value)
    end

    def hash_header_required_when_hash
      return unless loadbalancing == 'hash'
      return if hash_header.present?

      errors.add(:hash_header, 'is required when load balancing algorithm is hash')
    end

    def hash_header_not_allowed_when_not_hash
      return unless loadbalancing != 'hash' && hash_header.present?

      errors.add(:hash_header, 'can only be set when load balancing algorithm is hash')
    end

    def hash_balance_validation
      return if hash_balance_raw.nil?

      if loadbalancing != 'hash'
        errors.add(:hash_balance, 'can only be set when load balancing algorithm is hash')
        return
      end

      if @hash_balance_conversion_error
        errors.add(:hash_balance, "hash_balance must be a valid number")
        return
      end

      return if hash_balance >= 0.0 && hash_balance <= 100.0

      errors.add(:hash_balance, 'must be between 0.0 and 100.0')
    end
  end
end
