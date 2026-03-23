Sequel.migration do
  up do
    transaction do
      duplicates = self[:security_groups].select(:name).
                   group(:name).
                   having { count(1) > 1 }

      duplicates.each do |dup|
        ids_to_remove = self[:security_groups].
                        where(name: dup[:name]).
                        select(:id).
                        order(:id).
                        offset(1).
                        map(:id)
        self[:security_groups].where(id: ids_to_remove).delete
      end

      alter_table(:security_groups) do
        # Cannot add unique constraint concurrently as it requires a transaction
        # rubocop:disable Sequel/ConcurrentIndex
        drop_index :name, name: :sg_name_index if @db.indexes(:security_groups).key?(:sg_name_index)
        add_index :name, name: :security_group_name_index, unique: true unless @db.indexes(:security_groups).key?(:security_group_name_index)
        # rubocop:enable Sequel/ConcurrentIndex
      end
    end
  end

  down do
    alter_table(:security_groups) do
      # rubocop:disable Sequel/ConcurrentIndex
      drop_index :name, name: :security_group_name_index if @db.indexes(:security_groups).key?(:security_group_name_index)
      add_index :name, name: :sg_name_index unless @db.indexes(:security_groups).key?(:sg_name_index)
      # rubocop:enable Sequel/ConcurrentIndex
    end
  end
end
