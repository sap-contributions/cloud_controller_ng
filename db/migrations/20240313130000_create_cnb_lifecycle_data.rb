Sequel.migration do
  change do
    create_table(:cnb_lifecycle_data) do
      VCAP::Migration.common(self)

      String :build_guid, size: 255, null: true
      foreign_key [:build_guid], :builds, key: :guid, name: :fk_cnb_lifecycle_build_guid
      index [:build_guid], name: :fk_cnb_lifecycle_build_guid_index

      String :app_guid, size: 255, null: true
      foreign_key [:app_guid], :apps, key: :guid, name: :fk_cnb_lifecycle_app_guid
      index [:app_guid], name: :fk_cnb_lifecycle_app_guid_index

      String :droplet_guid, size: 255
      foreign_key [:droplet_guid], :droplets, key: :guid, name: :fk_cnb_lifecycle_droplet_guid
      index [:droplet_guid], name: :fk_cnb_lifecycle_droplet_guid_index
    end
  end
end
