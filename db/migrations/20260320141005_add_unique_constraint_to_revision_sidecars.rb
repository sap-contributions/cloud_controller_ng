Sequel.migration do
  no_transaction # required for concurrently option on postgres

  up do
    transaction do
      # remove duplicate entries if they exist
      duplicates = self[:revision_sidecars].
                   select(:revision_guid, :name).
                   group(:revision_guid, :name).
                   having { count(1) > 1 }

      duplicates.each do |dup|
        ids_to_remove = self[:revision_sidecars].
                        where(revision_guid: dup[:revision_guid], name: dup[:name]).
                        select(:id).
                        order(:id).
                        offset(1).
                        map(:id)
        self[:revision_sidecars].where(id: ids_to_remove).delete
      end
    end

    if database_type == :postgres
      VCAP::Migration.with_concurrent_timeout(self) do
        add_index :revision_sidecars, %i[revision_guid name],
                  name: :revision_sidecars_revision_guid_name_index,
                  unique: true,
                  concurrently: true,
                  if_not_exists: true
      end
    else
      alter_table(:revision_sidecars) do
        # rubocop:disable Sequel/ConcurrentIndex -- MySQL does not support concurrent index operations
        unless @db.indexes(:revision_sidecars).key?(:revision_sidecars_revision_guid_name_index)
          add_index %i[revision_guid name], unique: true,
                                            name: :revision_sidecars_revision_guid_name_index
        end
        # rubocop:enable Sequel/ConcurrentIndex
      end
    end
  end

  down do
    if database_type == :postgres
      VCAP::Migration.with_concurrent_timeout(self) do
        drop_index :revision_sidecars, nil,
                   name: :revision_sidecars_revision_guid_name_index,
                   concurrently: true,
                   if_exists: true
      end
    else
      alter_table(:revision_sidecars) do
        # rubocop:disable Sequel/ConcurrentIndex -- MySQL does not support concurrent index operations
        drop_index %i[revision_guid name], name: :revision_sidecars_revision_guid_name_index if @db.indexes(:revision_sidecars).key?(:revision_sidecars_revision_guid_name_index)
        # rubocop:enable Sequel/ConcurrentIndex
      end
    end
  end
end
