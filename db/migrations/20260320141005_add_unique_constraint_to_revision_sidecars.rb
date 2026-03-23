Sequel.migration do
  up do
    # remove duplicate entries if they exist
    transaction do
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

      alter_table(:revision_sidecars) do
        unless @db.indexes(:revision_sidecars).key?(:revision_sidecars_revision_guid_name_index)
          add_unique_constraint(%i[revision_guid name],
                                name: :revision_sidecars_revision_guid_name_index)
        end
      end
    end
  end

  down do
    alter_table(:revision_sidecars) do
      drop_constraint(:revision_sidecars_revision_guid_name_index, type: :unique) if @db.indexes(:revision_sidecars).key?(:revision_sidecars_revision_guid_name_index)
    end
  end
end
