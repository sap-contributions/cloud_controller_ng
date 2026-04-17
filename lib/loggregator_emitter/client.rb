require 'grpc'
require 'loggregator-api/v2/ingress_services_pb'

module LoggregatorEmitter
  class Client
    def initialize(endpoint:, origin:, source_type:, instance_id: nil, ca_cert_file: nil, client_cert_file: nil, client_key_file: nil)
      raise ArgumentError.new('Must provide a valid endpoint') if endpoint.nil? || endpoint.empty?
      raise ArgumentError.new('Must provide a valid origin') unless origin
      raise ArgumentError.new('Must provide a valid source_type') unless source_type

      @endpoint = endpoint
      @credentials = build_credentials(ca_cert_file, client_cert_file, client_key_file)
      @default_tags = { 'origin' => origin, 'source_type' => source_type }
      @instance_id = instance_id && instance_id.to_s
    end

    def emit(app_id, message, tags={})
      envelope = create_envelope(app_id, message, Loggregator::V2::Log::Type::OUT, tags)
      stub.send(Loggregator::V2::EnvelopeBatch.new(batch: [envelope]))
    end

    def emit_error(app_id, message, tags={})
      envelope = create_envelope(app_id, message, Loggregator::V2::Log::Type::ERR, tags)
      stub.send(Loggregator::V2::EnvelopeBatch.new(batch: [envelope]))
    end

    private

    def stub
      @stub ||= Loggregator::V2::Ingress::Stub.new(@endpoint, @credentials)
    end

    def create_envelope(app_id, message, type, tags)
      Loggregator::V2::Envelope.new(
        source_id: app_id,
        instance_id: @instance_id,
        timestamp: Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond),
        log: Loggregator::V2::Log.new(
          payload: message.encode('UTF-8'),
          type: type
        ),
        tags: @default_tags.merge(tags.transform_keys(&:to_s).transform_values(&:to_s))
      )
    end

    def build_credentials(ca_cert_file, client_cert_file, client_key_file)
      return :this_channel_is_insecure unless ca_cert_file && client_cert_file && client_key_file

      GRPC::Core::ChannelCredentials.new(
        File.read(ca_cert_file),
        File.read(client_key_file),
        File.read(client_cert_file)
      )
    end
  end
end
