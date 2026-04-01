require 'spec_helper'
require 'migrations/helpers/migration_shared_context'
RSpec.describe 'add unique constraint to sidecars', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20260323092954_add_unique_constraint_to_sidecars.rb' }
  end

  let!(:app) { VCAP::CloudController::AppModel.make }

  it 'remove duplicates, add constraint and revert migration' do
    # =========================================================================================
    # SETUP: Create duplicate entries to test the de-duplication logic.
    # =========================================================================================
    db[:sidecars].insert(guid: SecureRandom.uuid, name: 'app', command: 'command', app_guid: app.guid)
    db[:sidecars].insert(guid: SecureRandom.uuid, name: 'app', command: 'command', app_guid: app.guid)
    expect(db[:sidecars].where(name: 'app', app_guid: app.guid).count).to eq(2)

    # =========================================================================================
    # UP MIGRATION: Run the migration to apply the unique constraints.
    # ========================================================================================
    Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)

    # =========================================================================================
    # ASSERT UP MIGRATION: Verify that duplicates are removed and constraints are enforced.
    # =========================================================================================
    expect(db[:sidecars].where(name: 'app', app_guid: app.guid).count).to eq(1)
    expect(db.indexes(:sidecars)).to include(:sidecars_app_guid_name_index)
    expect { db[:sidecars].insert(guid: SecureRandom.uuid, name: 'app', command: 'command', app_guid: app.guid) }.to raise_error(Sequel::UniqueConstraintViolation)

    # =========================================================================================
    # TEST IDEMPOTENCY: Running the migration again should not cause any errors.
    # =========================================================================================
    expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

    # =========================================================================================
    # DOWN MIGRATION: Roll back the migration to remove the constraints.
    # =========================================================================================
    Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true)

    # =========================================================================================
    # ASSERT DOWN MIGRATION: Verify that constraints are removed and duplicates can be re-inserted.
    # =========================================================================================
    expect(db.indexes(:sidecars)).not_to include(:sidecars_app_guid_name_index)
    expect { db[:sidecars].insert(guid: SecureRandom.uuid, name: 'app', command: 'command', app_guid: app.guid) }.not_to raise_error
  end
end
