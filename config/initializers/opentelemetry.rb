require 'opentelemetry/sdk'
require 'opentelemetry-instrumentation-sinatra'

module CCInitializers
  def self.opentelemetry(cc_config)
    OpenTelemetry::SDK.configure do |c|
      c.use 'OpenTelemetry::Instrumentation::Sinatra'
    end
  end
end
