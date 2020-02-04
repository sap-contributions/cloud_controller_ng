module VCAP::CloudController
  class Membership
    SPACE_DEVELOPER = 'space_developer'.freeze
    SPACE_MANAGER = 'space_manager'.freeze
    SPACE_AUDITOR = 'space_auditor'.freeze
    ORG_USER = 'organization_user'.freeze
    ORG_MANAGER = 'organization_manager'.freeze
    ORG_AUDITOR = 'organization_auditor'.freeze
    ORG_BILLING_MANAGER = 'organization_billing_manager'.freeze

    SPACE_ROLES = %w(space_developer space_manager space_auditor).freeze
    ORG_ROLES = %w(organization_manager organization_billing_manager organization_auditor organization_user).freeze

    def initialize(user)
      @user = user
    end

    def has_any_roles?(roles, space_guid=nil, org_guid=nil)
      roles = [roles] unless roles.is_a?(Array)
      space_roles = roles & SPACE_ROLES
      org_roles = roles & ORG_ROLES

      space_role_dataset = Role.where(type: space_roles, user_id: @user.id)
      space_dataset = Space.join(space_role_dataset, space_id: :id).where(Sequel[:spaces][:guid] => space_guid).distinct.qualify(:spaces)

      org_role_dataset = Role.where(type: org_roles, user_id: @user.id)
      org_dataset = Organization.join(org_role_dataset, organization_id: :id).where(Sequel[:organizations][:guid] => org_guid).distinct.qualify(:organizations)

      space_dataset.any? || org_dataset.any?
    end

    def org_guids_for_roles(roles)
      roles = [roles] unless roles.is_a?(Array)
      org_roles = roles & ORG_ROLES

      org_role_dataset = Role.where(type: org_roles, user_id: @user.id)
      org_dataset_for_org_roles = Organization.join(org_role_dataset, organization_id: :id).distinct.qualify(:organizations)

      org_dataset_for_org_roles.map(&:guid)
    end

    def space_guids_for_roles(roles)
      roles = [roles] unless roles.is_a?(Array)
      space_roles = roles & SPACE_ROLES
      org_roles = roles & ORG_ROLES

      space_role_dataset = Role.where(type: space_roles, user_id: @user.id)
      space_dataset = Space.join(space_role_dataset, space_id: :id).distinct.qualify(:spaces)

      org_role_dataset = Role.where(type: org_roles, user_id: @user.id)
      space_dataset_for_org_roles = Space.join(org_role_dataset, organization_id: :organization_id).distinct.qualify(:spaces)

      space_guids_user_can_see = space_dataset_for_org_roles.union(space_dataset)

      space_guids_user_can_see.map(&:guid)
    end

    private

    def member_guids(roles: [])
      space_roles = roles & SPACE_ROLES
      org_roles = roles & ORG_ROLES

      space_role_dataset = Role.where(type: space_roles, user_id: @user.id)
      space_dataset = Space.join(space_role_dataset, space_id: :id).distinct.qualify(:spaces).select(:guid)

      org_role_dataset = Role.where(type: org_roles, user_id: @user.id)
      org_dataset = Organization.join(org_role_dataset, organization_id: :id).distinct.qualify(:organizations).select(:guid)

      space_dataset.union(org_dataset).map(&:guid)
      #
      # roles.map do |role|
      #   case role
      #   when SPACE_DEVELOPER
      #     @space_developer ||=
      #       @user.spaces_dataset.
      #         association_join(:organization).map(&:guid)
      #   when SPACE_MANAGER
      #     @space_manager ||=
      #       @user.managed_spaces_dataset.
      #         association_join(:organization).map(&:guid)
      #   when SPACE_AUDITOR
      #     @space_auditor ||=
      #       @user.audited_spaces_dataset.
      #         association_join(:organization).map(&:guid)
      #   when ORG_USER
      #     @org_user ||=
      #       @user.organizations_dataset.map(&:guid)
      #   when ORG_MANAGER
      #     @org_manager ||=
      #       @user.managed_organizations_dataset.map(&:guid)
      #   when ORG_AUDITOR
      #     @org_auditor ||=
      #       @user.audited_organizations_dataset.map(&:guid)
      #   when ORG_BILLING_MANAGER
      #     @org_billing_manager ||=
      #       @user.billing_managed_organizations_dataset.map(&:guid)
      #   end
      # end.flatten.compact
    end
  end
end