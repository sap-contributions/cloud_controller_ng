Sequel.migration do # rubocop:disable Metrics/BlockLength
  no_transaction # required for concurrently option on postgres

  up do
    transaction do
      duplicates = self[:revision_process_commands].
                   select(:revision_guid, :process_type).
                   group(:revision_guid, :process_type).
                   having { count(1) > 1 }

      duplicates.each do |dup|
        ids_to_remove = self[:revision_process_commands].
                        where(revision_guid: dup[:revision_guid], process_type: dup[:process_type]).
                        select(:id).
                        order(:id).
                        offset(1).
                        map(:id)
        self[:revision_process_commands].where(id: ids_to_remove).delete
      end
    end

    if database_type == :postgres
      VCAP::Migration.with_concurrent_timeout(self) do
        add_index :revision_process_commands, %i[revision_guid process_type],
                  name: :revision_process_commands_revision_guid_process_type_index,
                  unique: true,
                  concurrently: true,
                  if_not_exists: true
      end
    else
      alter_table(:revision_process_commands) do
        # rubocop:disable Sequel/ConcurrentIndex -- MySQL does not support concurrent index operations
        unless @db.indexes(:revision_process_commands).key?(:revision_process_commands_revision_guid_process_type_index)
          add_index %i[revision_guid process_type], unique: true,
                                                    name: :revision_process_commands_revision_guid_process_type_index
        end
        # rubocop:enable Sequel/ConcurrentIndex
      end
    end
  end

  down do
    if database_type == :postgres
      VCAP::Migration.with_concurrent_timeout(self) do
        drop_index :revision_process_commands, nil,
                   name: :revision_process_commands_revision_guid_process_type_index,
                   concurrently: true,
                   if_exists: true
      end
    else
      alter_table(:revision_process_commands) do
        # rubocop:disable Sequel/ConcurrentIndex -- MySQL does not support concurrent index operations
        if @db.indexes(:revision_process_commands).key?(:revision_process_commands_revision_guid_process_type_index)
          drop_index %i[revision_guid process_type],
                     name: :revision_process_commands_revision_guid_process_type_index
        end
        # rubocop:enable Sequel/ConcurrentIndex
      end
    end
  end
end
