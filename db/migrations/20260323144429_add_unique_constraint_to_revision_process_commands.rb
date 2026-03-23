Sequel.migration do
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

      alter_table(:revision_process_commands) do
        unless @db.indexes(:revision_process_commands).key?(:revision_process_commands_revision_guid_process_type_index)
          add_unique_constraint %i[revision_guid process_type],
                                name: :revision_process_commands_revision_guid_process_type_index
        end
      end
    end
  end

  down do
    alter_table(:revision_process_commands) do
      if @db.indexes(:revision_process_commands).key?(:revision_process_commands_revision_guid_process_type_index)
        drop_constraint(:revision_process_commands_revision_guid_process_type_index, type: :unique)
      end
    end
  end
end
