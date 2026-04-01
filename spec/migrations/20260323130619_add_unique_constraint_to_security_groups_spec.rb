require 'spec_helper'
require 'migrations/helpers/migration_shared_context'
RSpec.describe 'add unique constraint to security_groups', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20260323130619_add_unique_constraint_to_security_groups.rb' }
  end

  it 'remove duplicates, add constraint and revert migration' do
    # =========================================================================================
    # SETUP: Create duplicate entries to test the de-duplication logic.
    # =========================================================================================
    db[:security_groups].insert(guid: SecureRandom.uuid, name: 'sec1')
    db[:security_groups].insert(guid: SecureRandom.uuid, name: 'sec1')
    expect(db[:security_groups].where(name: 'sec1').count).to eq(2)

    # =========================================================================================
    # UP MIGRATION: Run the migration to apply the unique constraints.
    # ========================================================================================
    Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true)

    # =========================================================================================
    # ASSERT UP MIGRATION: Verify that duplicates are removed and constraints are enforced.
    # =========================================================================================
    expect(db[:security_groups].where(name: 'sec1').count).to eq(1)
    expect(db.indexes(:security_groups)).to include(:security_groups_name_index)
    expect { db[:security_groups].insert(guid: SecureRandom.uuid, name: 'sec1') }.to raise_error(Sequel::UniqueConstraintViolation)

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
    expect(db.indexes(:security_groups)).not_to include(:security_groups_name_index)
    expect(db.indexes(:security_groups)).to include(:sg_name_index)
    expect { db[:security_groups].insert(guid: SecureRandom.uuid, name: 'sec1') }.not_to raise_error
  end
end
