module VCAP::CloudController
  class RevisionProcessCommandModel < Sequel::Model(:revision_process_commands)
    many_to_one :revision,
                class: 'VCAP::CloudController::RevisionModel',
                primary_key: :guid,
                key: :revision_guid,
                without_guid_generation: true

    def around_save
      yield
    rescue Sequel::UniqueConstraintViolation => e
      raise e unless e.message.include?('revision_process_commands_revision_guid_process_type_index')

      errors.add(%i[revision_guid process_type], Sequel.lit("Process type '#{process_type}' already exists for given revision"))
      raise validation_failed_error
    end
  end
end
