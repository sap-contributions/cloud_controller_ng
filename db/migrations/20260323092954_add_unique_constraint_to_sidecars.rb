Sequel.migration do
  no_transaction # required for concurrently option on postgres

  up do
    transaction do
      duplicates = self[:sidecars].
                   select(:app_guid, :name).
                   group(:app_guid, :name).
                   having { count(1) > 1 }

      duplicates.each do |dup|
        ids_to_remove = self[:sidecars].
                        where(app_guid: dup[:app_guid], name: dup[:name]).
                        select(:id).
                        order(:id).
                        offset(1).
                        map(:id)

        self[:sidecars].where(id: ids_to_remove).delete
      end
    end

    if database_type == :postgres
      VCAP::Migration.with_concurrent_timeout(self) do
        add_index :sidecars, %i[app_guid name],
                  name: :sidecars_app_guid_name_index,
                  unique: true,
                  concurrently: true,
                  if_not_exists: true
      end
    else
      alter_table(:sidecars) do
        # rubocop:disable Sequel/ConcurrentIndex -- MySQL does not support concurrent index operations
        unless @db.indexes(:sidecars).key?(:sidecars_app_guid_name_index)
          add_index %i[app_guid name], unique: true,
                                       name: :sidecars_app_guid_name_index
        end
        # rubocop:enable Sequel/ConcurrentIndex
      end
    end
  end

  down do
    if database_type == :postgres
      VCAP::Migration.with_concurrent_timeout(self) do
        drop_index :sidecars, nil,
                   name: :sidecars_app_guid_name_index,
                   concurrently: true,
                   if_exists: true
      end
    else
      alter_table(:sidecars) do
        # rubocop:disable Sequel/ConcurrentIndex -- MySQL does not support concurrent index operations
        drop_index %i[app_guid name], name: :sidecars_app_guid_name_index if @db.indexes(:sidecars).key?(:sidecars_app_guid_name_index)
        # rubocop:enable Sequel/ConcurrentIndex
      end
    end
  end
end
