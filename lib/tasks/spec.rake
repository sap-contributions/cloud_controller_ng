desc 'Runs all specs'
task spec: 'spec:all'

namespace :spec do
  task all: ['db:pick', 'db:parallel:recreate'] do
    if ARGV[1]
      run_specs(ARGV[1])
    else
      run_specs_parallel('spec')
    end
  end

  task cnb: ['db:pick', 'db:parallel:recreate'] do
    run_specs('spec/unit/models/runtime/app_model_spec.rb')
    run_specs('spec/unit/models/runtime/build_model_spec.rb')
    run_specs('spec/unit/models/runtime/droplet_model_spec.rb')
    run_specs('spec/unit/actions/build_create_spec.rb')
    run_specs('spec/unit/models/runtime/cnb_lifecycle_data_model_spec.rb')
    run_specs('spec/unit/lib/cloud_controller/diego/cnb/lifecycle_data_spec.rb')
    run_specs('spec/unit/lib/cloud_controller/diego/cnb/staging_action_builder_spec.rb')
    run_specs('spec/unit/lib/cloud_controller/diego/cnb/staging_completion_handler_spec.rb')
    run_specs('spec/unit/lib/cloud_controller/diego/cnb/lifecycle_protocol_spec.rb')
    run_specs('spec/unit/lib/cloud_controller/diego/lifecycles/app_cnb_lifecycle_spec.rb')
    run_specs('spec/unit/lib/utils/uri_utils_spec.rb')
    run_specs('spec/unit/messages/validators_spec.rb')
    run_specs('spec/unit/lib/cloud_controller/errands/rotate_database_key_spec.rb')
    run_specs('spec/unit/messages/app_create_message_spec.rb')
    run_specs('spec/unit/models/runtime/buildpack_lifecycle_buildpack_model_spec.rb')
  end

  task serial: ['db:pick', 'db:recreate'] do
    run_specs(ARGV[1] || 'spec')
  end

  task integration: ['db:pick', 'db:recreate'] do
    run_specs('spec/integration')
  end

  desc 'Run only previously failing tests'
  task failed: 'db:pick' do
    run_failed_specs
  end

  desc 'Run tests on already migrated databases'
  task without_migrate: ['db:pick'] do
    # We exclude specs that test migration behaviour since this breaks/alters the DB in the middle of a test
    if ARGV[1]
      run_specs(ARGV[1], 'NO_DB_MIGRATION=true')
    else
      run_specs_parallel('spec', 'NO_DB_MIGRATION=true')
    end
  end

  def run_specs(path, env_vars='')
    sh "#{env_vars} bundle exec rspec #{path} --require rspec/instafail --format RSpec::Instafail --format progress"
  end

  def run_specs_parallel(path, env_vars='')
    sh "#{env_vars} bundle exec parallel_rspec --test-options '--order rand' --single spec/integration/ --single spec/acceptance/ -- #{path}"
  end

  def run_failed_specs
    sh 'bundle exec rspec --only-failures --color --tty spec --require rspec/instafail --format RSpec::Instafail'
  end
end
