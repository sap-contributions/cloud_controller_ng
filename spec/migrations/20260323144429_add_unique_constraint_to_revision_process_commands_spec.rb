require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'add unique constraint to revision_process_commands', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20260323144429_add_unique_constraint_to_revision_process_commands.rb' }
  end

  let!(:revision) { VCAP::CloudController::RevisionModel.make }

  it 'removes duplicates, adds constraint and reverts migration' do
    # =========================================================================================
    # SETUP: Create duplicate entries to test the de-duplication logic.
    # =========================================================================================
    db[:revision_process_commands].insert(guid: SecureRandom.uuid, revision_guid: revision.guid, process_type: 'worker')
    db[:revision_process_commands].insert(guid: SecureRandom.uuid, revision_guid: revision.guid, process_type: 'worker')
    expect(db[:revision_process_commands].where(revision_guid: revision.guid, process_type: 'worker').count).to eq(2)

    # =========================================================================================
    # UP MIGRATION: Run the migration to apply the unique constraints.
    # =========================================================================================
    Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)

    # =========================================================================================
    # ASSERT UP MIGRATION: Verify that duplicates are removed and constraints are enforced.
    # =========================================================================================
    expect(db[:revision_process_commands].where(revision_guid: revision.guid, process_type: 'worker').count).to eq(1)
    expect(db.indexes(:revision_process_commands)).to include(:revision_process_commands_revision_guid_process_type_index)
    expect do
      db[:revision_process_commands].insert(guid: SecureRandom.uuid, revision_guid: revision.guid, process_type: 'worker')
    end.to raise_error(Sequel::UniqueConstraintViolation)

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
    expect(db.indexes(:revision_process_commands)).not_to include(:revision_process_commands_revision_guid_process_type_index)
    expect do
      db[:revision_process_commands].insert(guid: SecureRandom.uuid, revision_guid: revision.guid, process_type: 'worker')
    end.not_to raise_error
  end
end
