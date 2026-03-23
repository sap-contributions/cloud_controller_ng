module VCAP::CloudController
  class SidecarModel < Sequel::Model(:sidecars)
    include SidecarMixin

    ORIGIN_USER = 'user'.freeze
    ORIGIN_BUILDPACK = 'buildpack'.freeze

    many_to_one :app,
                class: 'VCAP::CloudController::AppModel',
                key: :app_guid,
                primary_key: :guid,
                without_guid_generation: true

    one_to_many :sidecar_process_types,
                class: 'VCAP::CloudController::SidecarProcessTypeModel',
                key: :sidecar_guid,
                primary_key: :guid

    def around_save
      yield
    rescue Sequel::UniqueConstraintViolation => e
      raise e unless e.message.include?('sidecars_app_guid_name_index')

      errors.add(%i[app_guid name], Sequel.lit("Sidecar with name '#{name}' already exists for given app"))
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
