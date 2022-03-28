ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
$LOAD_PATH.unshift(File.expand_path('../app', __dir__))
$LOAD_PATH.unshift(File.expand_path('../middleware', __dir__))

require 'rubygems'
require 'bundler/setup' # Set up gems listed in the Gemfile.

OpenTelemetry::SDK.configure do |c|
  c.use_all
end
