source 'https://rubygems.org'

gem 'addressable'
gem 'allowy', '>= 2.1.0'
gem 'cf-copilot', '0.0.14'
gem 'clockwork', require: false
gem 'cloudfront-signer'
gem 'em-http-request', '~> 1.1'
gem 'eventmachine', '~> 1.2.7'
gem 'fluent-logger'
gem 'googleapis-common-protos', '>= 1.3.12'
gem 'hashdiff'
gem 'honeycomb-beeline'
gem 'httpclient'
gem 'json-diff'
gem 'json-schema'
gem 'json_pure'
gem 'loggregator_emitter', '~> 5.0'
gem 'membrane', '~> 1.0'
gem 'mime-types', '~> 3.5'
gem 'mock_redis'
gem 'multi_json'
gem 'multipart-parser'
gem 'net-ssh'
gem 'netaddr', '>= 2.0.4'
gem 'newrelic_rpm'
gem 'nokogiri', '>=1.10.5'
gem 'oj'
gem 'palm_civet'
gem 'posix-spawn', '~> 0.3.15'
gem 'public_suffix'
gem 'psych', '>= 4.0.4'
gem 'rake'
gem 'redis'
gem 'retryable'
gem 'rfc822'
gem 'rubyzip', '>= 1.3.0'
gem 'sequel', '~> 5.72'
gem 'sequel_pg', require: 'sequel'
gem 'sinatra', '~> 3.1'
gem 'sinatra-contrib'
gem 'statsd-ruby', '~> 1.5.0'
gem 'prometheus-client'
gem 'steno'
gem 'talentbox-delayed_job_sequel', '~> 4.3.0'
gem 'thin'
gem 'puma'
gem 'unf'
gem 'vmstat', '~> 2.3'
gem 'yajl-ruby'

# Rails Components
gem 'actionpack', '~> 7.1.0'
gem 'actionview', '~> 7.1.0'
gem 'activemodel', '~> 7.1.0'
gem 'railties', '~> 7.1.0'

gem 'azure-storage-blob', git: 'https://github.com/sethboyles/azure-storage-ruby.git', branch: 'x-ms-blob-content-type-fix-1.1'

gem 'fog-aliyun'
gem 'fog-aws'
gem 'fog-azure-rm', git: 'https://github.com/fog/fog-azure-rm.git', branch: 'fog-arm-cf'
gem 'fog-google', '~> 1.22.0'
gem 'fog-local'
gem 'fog-openstack'
gem 'fog-core', '~> 2.1.2'

gem 'cf-uaa-lib', '~> 4.0.3'
gem 'vcap-concurrency', git: 'https://github.com/cloudfoundry/vcap-concurrency.git', ref: '2a5b0179'

group :db do
  gem 'mysql2', '~> 0.5.5'
  gem 'pg'
end

group :operations do
  gem 'pry-byebug'
end

group :test do
  gem 'codeclimate-test-reporter', '>= 1.0.8', require: false
  gem 'machinist', '~> 1.0.6'
  gem 'parallel_tests'
  gem 'rack-test'
  gem 'rspec', '~> 3.12.0'
  gem 'rspec-collection_matchers'
  gem 'rspec-instafail'
  gem 'rspec-its'
  gem 'rspec-rails', '~> 6.0.3'
  gem 'rspec-wait'
  gem 'rspec_api_documentation', '>= 6.1.0'
  gem 'rubocop', '~> 1.56.2'
  gem 'timecop'
  gem 'webmock', '> 2.3.1'
end

group :development do
  gem 'byebug'
  gem 'listen'
  gem 'roodi'
  gem 'solargraph'
  gem 'spork', git: 'https://github.com/sporkrb/spork', ref: '224df49' # '~> 1.0rc'
  gem 'spring'
  gem 'spring-commands-rspec'
  gem 'debug', '~> 1.8'
end
