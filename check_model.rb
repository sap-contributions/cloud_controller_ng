#!/usr/bin/env ruby

require_relative 'config/boot'
require 'cloud_controller'

config_file = ENV['CLOUD_CONTROLLER_NG_CONFIG']
config = VCAP::CloudController::Config.load_from_file(config_file)
db_config = config.get(:db)

begin
  require_relative 'spec/support/bootstrap/db_config.rb'
  db_config[:database] ||= DbConfig.new.config[:database]
rescue LoadError
  # db_config should already contain the database connection
end

logger = Logger.new($stdout)

VCAP::CloudController::DB.load_models_without_migrations_check(db_config, logger)
::Delayed::Worker.backend = :sequel

logger.info('Checking models...')

used_columns = MultiJson.load(File.read('./db/used_columns.json'))
used_columns.each do |model_class, columns|
  logger.info("Checking class #{model_class}")
  model_class.constantize.select(*columns.map(&:to_sym)).first
end

logger.info('Done.')
