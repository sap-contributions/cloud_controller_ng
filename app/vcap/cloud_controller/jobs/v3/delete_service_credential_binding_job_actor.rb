module VCAP::CloudController
  module V3
    class DeleteServiceCredentialBindingJobActor
      def display_name
        'service_bindings.delete'
      end

      def resource_type
        'service_credential_binding'
      end

      def get_resource(resource_id)
        ServiceBinding.first(guid: resource_id)
      end
    end
  end
end
