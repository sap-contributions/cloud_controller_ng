Sequel.migration do
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

      alter_table(:sidecars) do
        unless @db.indexes(:sidecars).key?(:sidecars_app_guid_name_index)
          add_unique_constraint %i[app_guid name],
                                name: :sidecars_app_guid_name_index
        end
      end
    end
  end

  down do
    alter_table(:sidecars) do
      drop_constraint(:sidecars_app_guid_name_index, type: :unique) if @db.indexes(:sidecars).key?(:sidecars_app_guid_name_index)
    end
  end
end
