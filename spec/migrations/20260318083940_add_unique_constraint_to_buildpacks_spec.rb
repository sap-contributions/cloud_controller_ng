require 'spec_helper'
require 'migrations/helpers/migration_shared_context'

RSpec.describe 'add unique constraint to buildpacks', isolation: :truncation, type: :migration do
  include_context 'migration' do
    let(:migration_filename) { '20260318083940_add_unique_constraint_to_buildpacks.rb' }
  end

  describe 'buildpacks table' do
    it 'drops old index, adds new unique index, and handles idempotency' do
      # Verify initial state - old index exists, new one does not
      expect(db.indexes(:buildpacks)).to include(:unique_name_and_stack)
      expect(db.indexes(:buildpacks)).not_to include(:buildpacks_name_stack_lifecycle_index)

      # === UP MIGRATION ===
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

      # Verify old index is dropped and new index is added
      expect(db.indexes(:buildpacks)).not_to include(:unique_name_and_stack)
      expect(db.indexes(:buildpacks)).to include(:buildpacks_name_stack_lifecycle_index)

      # Test up migration idempotency
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error
      expect(db.indexes(:buildpacks)).not_to include(:unique_name_and_stack)
      expect(db.indexes(:buildpacks)).to include(:buildpacks_name_stack_lifecycle_index)

      # === DOWN MIGRATION ===
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error

      # Verify new index is dropped and old index is restored
      expect(db.indexes(:buildpacks)).not_to include(:buildpacks_name_stack_lifecycle_index)
      expect(db.indexes(:buildpacks)).to include(:unique_name_and_stack)

      # Test down migration idempotency
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index - 1, allow_missing_migration_files: true) }.not_to raise_error
      expect(db.indexes(:buildpacks)).not_to include(:buildpacks_name_stack_lifecycle_index)
      expect(db.indexes(:buildpacks)).to include(:unique_name_and_stack)
    end

    it 'removes duplicate entries before adding the unique index' do
      # Drop old unique index so we can insert duplicates
      db.alter_table(:buildpacks) { drop_index %i[name stack], name: :unique_name_and_stack }

      db[:buildpacks].insert(guid: SecureRandom.uuid, name: 'ruby', stack: 'cflinuxfs3', lifecycle: 'buildpack', position: 1)
      db[:buildpacks].insert(guid: SecureRandom.uuid, name: 'ruby', stack: 'cflinuxfs3', lifecycle: 'buildpack', position: 2)
      db[:buildpacks].insert(guid: SecureRandom.uuid, name: 'ruby', stack: 'cflinuxfs3', lifecycle: 'cnb', position: 3)
      db[:buildpacks].insert(guid: SecureRandom.uuid, name: 'ruby', stack: 'cflinuxfs4', lifecycle: 'buildpack', position: 4)
      db[:buildpacks].insert(guid: SecureRandom.uuid, name: 'go', stack: 'cflinuxfs3', lifecycle: 'buildpack', position: 5)
      db[:buildpacks].insert(guid: SecureRandom.uuid, name: 'go', stack: 'cflinuxfs3', lifecycle: 'buildpack', position: 6)
      db[:buildpacks].insert(guid: SecureRandom.uuid, name: 'go', stack: 'cflinuxfs3', lifecycle: 'buildpack', position: 7)

      # Verify duplicates exist before migration
      expect(db[:buildpacks].where(name: 'ruby', stack: 'cflinuxfs3', lifecycle: 'buildpack').count).to eq(2)
      expect(db[:buildpacks].where(name: 'go', stack: 'cflinuxfs3', lifecycle: 'buildpack').count).to eq(3)

      # === UP MIGRATION ===
      expect { Sequel::Migrator.run(db, migrations_path, target: current_migration_index, allow_missing_migration_files: true) }.not_to raise_error

      # Verify duplicates are removed, keeping one per (name, stack, lifecycle)
      expect(db[:buildpacks].where(name: 'ruby', stack: 'cflinuxfs3', lifecycle: 'buildpack').count).to eq(1)
      expect(db[:buildpacks].where(name: 'ruby', stack: 'cflinuxfs3', lifecycle: 'cnb').count).to eq(1)
      expect(db[:buildpacks].where(name: 'ruby', stack: 'cflinuxfs4', lifecycle: 'buildpack').count).to eq(1)
      expect(db[:buildpacks].where(name: 'go', stack: 'cflinuxfs3', lifecycle: 'buildpack').count).to eq(1)

      # Verify new index exists
      expect(db.indexes(:buildpacks)).to include(:buildpacks_name_stack_lifecycle_index)
    end
  end
end
