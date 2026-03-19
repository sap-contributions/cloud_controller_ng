module VCAP::CloudController
  class ServicePlanVisibility < Sequel::Model
    many_to_one :service_plan
    many_to_one :organization

    import_attributes :service_plan_guid, :organization_guid
    export_attributes :service_plan_guid, :organization_guid

    def around_save
      yield
    rescue Sequel::UniqueConstraintViolation => e
      raise e unless e.message.include?('spv_org_id_sp_id_index')

      errors.add(%i[organization_id service_plan_id], :unique)
      raise validation_failed_error
    end

    def validate
      validates_presence :service_plan
      validates_presence :organization
      validate_plan_is_not_private
      validate_plan_is_not_public
    end

    def self.visible_private_plan_ids_for_user(user)
      visible_private_plan_ids_for_organization(user.membership_org_ids).distinct
    end

    def self.visible_private_plan_ids_for_organization(org_id)
      dataset.where(organization_id: org_id).select(:service_plan_id)
    end

    private

    def validate_plan_is_not_private
      return unless service_plan&.broker_space_scoped?

      errors.add(:service_plan, 'is from a private broker')
    end

    def validate_plan_is_not_public
      return unless service_plan&.public?

      errors.add(:service_plan, 'is publicly available')
    end
  end
end
