module VCAP::CloudController
  class RevisionSidecarModel < Sequel::Model(:revision_sidecars)
    include SidecarMixin

    many_to_one :revision,
                class: 'VCAP::CloudController::RevisionModel',
                key: :revision_guid,
                primary_key: :guid,
                without_guid_generation: true

    one_to_many :revision_sidecar_process_types,
                class: 'VCAP::CloudController::RevisionSidecarProcessTypeModel',
                key: :revision_sidecar_guid,
                primary_key: :guid

    alias_method :sidecar_process_types, :revision_sidecar_process_types

    add_association_dependencies revision_sidecar_process_types: :destroy

    def around_save
      yield
    rescue Sequel::UniqueConstraintViolation => e
      raise e unless e.message.include?('revision_sidecars_revision_guid_name_index')

      errors.add(%i[revision_guid name], Sequel.lit("Sidecar with name '#{name}' already exists for revision '#{revision_guid}'"))
      raise validation_failed_error
    end

    def validate
      super
      validates_presence %i[name command]
      validates_max_length 255, :name, message: Sequel.lit('Name is too long (maximum is 255 characters)')
      validates_max_length 4096, :command, message: Sequel.lit('Command is too long (maximum is 4096 characters)')
    end
  end
end
