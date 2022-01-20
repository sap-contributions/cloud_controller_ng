module VCAP::CloudController
  module ServiceCredentialBindingCreateMixin
    private

    def validate_service_key_quotas!(errors, validation_error_handler)
      quota_errors = errors.on(:quota).to_a

      if quota_errors.include?(:service_keys_space_quota_exceeded)
        validation_error_handler.error!("You have exceeded your space's limit for service binding of type key.")
      elsif quota_errors.include?(:service_keys_quota_exceeded)
        validation_error_handler.error!("You have exceeded your organization's limit for service binding of type key.")
      end
    end

    def key_validation_error!(
      exception,
      name:,
      validation_error_handler:
    )
      errors = exception.errors
      validate_service_key_quotas!(errors, validation_error_handler)

      if errors.on([:name, :service_instance_id])&.include?(:unique)
        key_unique_error!(name, validation_error_handler)
      end

      validation_error_handler.error!(exception.message)
    end

    def key_unique_error!(name, validation_error_handler)
      validation_error_handler.error!("The binding name is invalid. Key binding names must be unique. The service instance already has a key binding with name '#{name}'.")
    end
  end
end
