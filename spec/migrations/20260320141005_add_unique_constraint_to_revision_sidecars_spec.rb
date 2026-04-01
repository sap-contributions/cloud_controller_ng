require 'spec_helper'
require 'migrations/helpers/migration_shared_context'
RSpec.describe 'add unique constraint to revision sidecar types', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20260320141005_add_unique_constraint_to_revision_sidecars.rb' }
  end

  let!(:app) { VCAP::CloudController::AppModel.make }
  let!(:revision) { VCAP::CloudController::RevisionModel.make(:app) }

  it 'remove duplicates, add constraint and revert migration' do
    # =========================================================================================
    # SETUP: Create duplicate entries to test the de-duplication logic.
    # =========================================================================================
    db[:revision_sidecars].insert(guid: SecureRandom.uuid, name: 'app', command: 'command', revision_guid: revision.guid)
    db[:revision_sidecars].insert(guid: SecureRandom.uuid, name: 'app', command: 'command', revision_guid: revision.guid)
    expect(db[:revision_sidecars].where(name: 'app', revision_guid: revision.guid).count).to eq(2)

    # =========================================================================================
    # UP MIGRATION: Run the migration to apply the unique constraints.
    # ========================================================================================
    Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)

    # =========================================================================================
    # ASSERT UP MIGRATION: Verify that duplicates are removed and constraints are enforced.
    # =========================================================================================
    expect(db[:revision_sidecars].where(name: 'app', revision_guid: revision.guid).count).to eq(1)
    expect(db.indexes(:revision_sidecars)).to include(:revision_sidecars_revision_guid_name_index)
    expect { db[:revision_sidecars].insert(guid: SecureRandom.uuid, name: 'app', command: 'command', revision_guid: revision.guid) }.to raise_error(Sequel::UniqueConstraintViolation)

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
    expect(db.indexes(:revision_sidecars)).not_to include(:revision_sidecars_revision_guid_name_index)
    expect { db[:revision_sidecars].insert(guid: SecureRandom.uuid, name: 'app', command: 'command', revision_guid: revision.guid) }.not_to raise_error
  end
end
