Sequel.migration do
  change do
    alter_table :cnb_lifecycle_data do
      add_column :encrypted_registry_credentials_json, String
      add_column :credentials_salt, String, size: 255
      add_column :encryption_key_label, String, size: 255
      add_column :encryption_iterations, Integer, default: 2048, null: false
    end
  end
end
