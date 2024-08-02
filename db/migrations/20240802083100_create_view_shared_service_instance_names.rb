# rubocop:disable Sequel/ConcurrentIndex
Sequel.migration do
  up do
    next unless database_type == :postgres

    unless views.include?(:si_and_shared_si_names_with_space_and_target_space_guids)
      si_names_and_space_guids =
        self[:service_instances].
        join(:spaces, id: :service_instances__space_id). # to get the space_guid
        join(:service_instance_shares, target_space_guid: :spaces__guid).distinct. # only service instances in spaces that are also targets
        select(:service_instances__name___service_instance_name, :spaces__guid___space_guid)

      shared_si_names_and_target_space_guids =
        self[:service_instance_shares].
        join(:service_instances, guid: :service_instance_shares__service_instance_guid). # to get the service_instance_name
        select(:service_instances__name___service_instance_name, :service_instance_shares__target_space_guid___space_guid)

      si_and_shared_si_names_with_space_and_target_space_guids =
        si_names_and_space_guids.union(shared_si_names_and_target_space_guids, all: true)

      create_view :si_and_shared_si_names_with_space_and_target_space_guids, si_and_shared_si_names_with_space_and_target_space_guids, materialized: true
    end

    add_index :si_and_shared_si_names_with_space_and_target_space_guids, %i[service_instance_name space_guid],
              name: :si_and_shared_si_names_with_space_and_target_space_guids_index, unique: true, if_not_exists: true
  end

  down do
    next unless database_type == :postgres

    drop_index :si_and_shared_si_names_with_space_and_target_space_guids, nil, name: :si_and_shared_si_names_with_space_and_target_space_guids_index, if_exists: true

    drop_view :si_and_shared_si_names_with_space_and_target_space_guids, materialized: true, if_exists: true
  end
end
# rubocop:enable Sequel/ConcurrentIndex
