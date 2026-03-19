Sequel.migration do
  up do
    transaction do
      # Remove duplicate entries if they exist
      duplicates = self[:buildpacks].
                   select(:name, :stack, :lifecycle).
                   group(:name, :stack, :lifecycle).
                   having { count(1) > 1 }

      duplicates.each do |dup|
        ids_to_remove = self[:buildpacks].
                        where(name: dup[:name], stack: dup[:stack], lifecycle: dup[:lifecycle]).
                        select(:id).
                        order(:id).
                        offset(1).
                        map(:id)

        self[:buildpacks].where(id: ids_to_remove).delete
      end

      alter_table(:buildpacks) do
        # rubocop:disable Sequel/ConcurrentIndex
        drop_index %i[name stack], name: :unique_name_and_stack if @db.indexes(:buildpacks).key?(:unique_name_and_stack)
        unless @db.indexes(:buildpacks).key?(:buildpacks_name_stack_lifecycle_index)
          add_index %i[name stack lifecycle], unique: true,
                                              name: :buildpacks_name_stack_lifecycle_index
        end
        # rubocop:enable Sequel/ConcurrentIndex
      end
    end
  end

  down do
    alter_table(:buildpacks) do
      # rubocop:disable Sequel/ConcurrentIndex
      drop_index %i[name stack lifecycle], name: :buildpacks_name_stack_lifecycle_index if @db.indexes(:buildpacks).key?(:buildpacks_name_stack_lifecycle_index)
      add_index %i[name stack], unique: true, name: :unique_name_and_stack unless @db.indexes(:buildpacks).key?(:unique_name_and_stack)
      # rubocop:enable Sequel/ConcurrentIndex
    end
  end
end
