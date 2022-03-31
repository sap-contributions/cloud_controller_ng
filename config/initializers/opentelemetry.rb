require 'opentelemetry/sdk'
require 'opentelemetry-instrumentation-delayed_job'
require 'opentelemetry-instrumentation-sinatra'
require 'opentelemetry-instrumentation-pg'
require 'opentelemetry/exporter/otlp'

module CCInitializers
  def self.opentelemetry(cc_config)
    OpenTelemetry::SDK.configure do |c|
      c.use 'OpenTelemetry::Instrumentation::DelayedJob'
      c.use 'OpenTelemetry::Instrumentation::PG'
      c.use 'OpenTelemetry::Instrumentation::Sinatra'
    end
  end
end
