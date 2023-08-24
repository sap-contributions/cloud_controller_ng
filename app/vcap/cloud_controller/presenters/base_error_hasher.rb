require 'cloud_controller/structured_error'

module VCAP::CloudController
  class BaseErrorHasher < Struct.new(:error)
    def sanitized_hash
      unsanitized_hash.keep_if { |k, _| allowed_keys.include? k }
    end

    def unsanitized_hash
      {}
    end

    def compound_error?
      error.respond_to?(:underlying_errors)
    end

    def api_error?
      error.respond_to?(:code)
    end

    def services_error?
      error.is_a?(StructuredError)
    end

    private

    def allowed_keys
      []
    end

    def unknown_error_hash
      raise NotImplementedError
    end
  end
end
