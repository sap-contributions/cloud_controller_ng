require 'opentelemetry/instrumentation/all'
require 'opentelemetry/exporter/otlp'
require 'opentelemetry/sdk'

module CCInitializers
  def self.opentelemetry(cc_config)
    otel_exporter = OpenTelemetry::Exporter::OTLP::Exporter.new
    processor = OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(otel_exporter)

    OpenTelemetry::SDK.configure do |c|
      c.service_name = 'cf_cloud_controller'
      c.service_version = '1.128.0dev.2'
      c.add_span_processor(processor)
      c.use_all()
    end
  end
end
