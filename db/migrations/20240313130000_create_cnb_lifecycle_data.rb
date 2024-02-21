Sequel.migration do
  change do
    create_table(:cnb_lifecycle_data) do
      VCAP::Migration.common(self, :cnb_lifecycle_data)

      String :build_guid
      foreign_key [:build_guid], :builds, key: :guid, name: :fk_cnb_lifecycle_build_guid, on_delete: :cascade
      index [:build_guid], name: :fk_cnb_lifecycle_build_guid_index

      String :app_guid
      index [:app_guid], name: :fk_cnb_lifecycle_app_guid_index

      String :droplet_guid
      index [:droplet_guid], name: :fk_cnb_lifecycle_droplet_guid_index

      String :stack
    end

    alter_table(:buildpack_lifecycle_buildpacks) do
      add_column :cnb_lifecycle_data_guid, String, null: true

      add_foreign_key [:cnb_lifecycle_data_guid], :cnb_lifecycle_data, key: :guid, name: :fk_blcnb_bldata_guid
      add_index [:cnb_lifecycle_data_guid], name: :bl_cnb_bldata_guid_index

      set_column_allow_null :cnb_lifecycle_data_guid
    end
  end
end
