require 'diego/bbs/bbs'
require 'diego/errors'
require 'diego/routes'
require 'uri'
require 'resolv'
require 'faraday'
# require 'faraday/net_http_persistent'


module Diego
  class Client
    def initialize(url:, ca_cert_file:, client_cert_file:, client_key_file:,
      connect_timeout:, send_timeout:, receive_timeout:)
      ENV['PB_IGNORE_DEPRECATIONS'] ||= 'true'
      @bbs_url = URI(url)
      @http_client = faraday(
        ca_cert_file,
        client_cert_file,
        client_key_file,
        connect_timeout,
        send_timeout,
        receive_timeout)
    end

    def ping
      puts("#{Thread.current.object_id}: start a ping")
      req = post_request(path: Routes::PING)
      puts("#{Thread.current.object_id}: post ping")
      response = request_with_error_handling(req)
      puts("#{Thread.current.object_id}: Response #{response.body}")

      validate_status!(response)
      # protobuf_decode!(response.body, Bbs::Models::PingResponse)
    end

    def upsert_domain(domain:, ttl:)
      req = post_request(body: protobuf_encode!({ domain: domain, ttl: ttl.to_i }, Bbs::Models::UpsertDomainRequest), path: Routes::UPSERT_DOMAIN)
      response = request_with_error_handling(req)

      validate_status!(response)
      protobuf_decode!(response.body, Bbs::Models::UpsertDomainResponse)
    end

    def desire_task(task_definition:, domain:, task_guid:)
      req = post_request(body: protobuf_encode!({ task_definition: task_definition, domain: domain, task_guid: task_guid }, Bbs::Models::DesireTaskRequest),
path: Routes::DESIRE_TASK)
      response = request_with_error_handling(req)

      validate_status!(response)
      protobuf_decode!(response.body, Bbs::Models::TaskLifecycleResponse)
    end

    def task_by_guid(task_guid)
      req = post_request(body: protobuf_encode!({ task_guid: task_guid }, Bbs::Models::TaskByGuidRequest), path: Routes::TASK_BY_GUID)
      response = request_with_error_handling(req)

      validate_status!(response)
      protobuf_decode!(response.body, Bbs::Models::TaskResponse)
    end

    def tasks(domain: '', cell_id: '')
      req = post_request(body: protobuf_encode!({ domain: domain, cell_id: cell_id }, Bbs::Models::TasksRequest), path: Routes::LIST_TASKS)
      response = request_with_error_handling(req)

      validate_status!(response)
      protobuf_decode!(response.body, Bbs::Models::TasksResponse)
    end

    def cancel_task(task_guid)
      req = post_request(body: protobuf_encode!({ task_guid: task_guid }, Bbs::Models::TaskGuidRequest), path: Routes::CANCEL_TASK)
      response = request_with_error_handling(req)

      validate_status!(response)
      protobuf_decode!(response.body, Bbs::Models::TaskLifecycleResponse)
    end

    def desire_lrp(lrp)
      req = post_request(body: protobuf_encode!({ desired_lrp: lrp }, Bbs::Models::DesireLRPRequest), path: Routes::DESIRE_LRP)
      response = request_with_error_handling(req)

      validate_status!(response)
      protobuf_decode!(response.body, Bbs::Models::DesiredLRPLifecycleResponse)
    end

    def desired_lrp_by_process_guid(process_guid)
      req = post_request(body: protobuf_encode!({ process_guid: process_guid }, Bbs::Models::DesiredLRPByProcessGuidRequest), path: Routes::DESIRED_LRP_BY_PROCESS_GUID)
      response = request_with_error_handling(req)

      validate_status!(response)
      protobuf_decode!(response.body, Bbs::Models::DesiredLRPResponse)
    end

    def update_desired_lrp(process_guid, lrp_update)
      req = post_request(body: protobuf_encode!({ process_guid: process_guid, update: lrp_update }, Bbs::Models::UpdateDesiredLRPRequest), path: Routes::UPDATE_DESIRED_LRP)
      response = request_with_error_handling(req)

      validate_status!(response)
      protobuf_decode!(response.body, Bbs::Models::DesiredLRPLifecycleResponse)
    end

    def remove_desired_lrp(process_guid)
      req = post_request(body: protobuf_encode!({ process_guid: process_guid }, Bbs::Models::RemoveDesiredLRPRequest), path: Routes::REMOVE_DESIRED_LRP)
      response = request_with_error_handling(req)

      validate_status!(response)
      protobuf_decode!(response.body, Bbs::Models::DesiredLRPLifecycleResponse)
    end

    def retire_actual_lrp(actual_lrp_key)
      req = post_request(body: protobuf_encode!({ actual_lrp_key: actual_lrp_key }, Bbs::Models::RetireActualLRPRequest), path: Routes::RETIRE_ACTUAL_LRP)
      response = request_with_error_handling(req)

      validate_status!(response)
      protobuf_decode!(response.body, Bbs::Models::ActualLRPLifecycleResponse)
    end

    def desired_lrp_scheduling_infos(domain)
      req = post_request(body: protobuf_encode!({ domain: domain }, Bbs::Models::DesiredLRPsRequest), path: Routes::DESIRED_LRP_SCHEDULING_INFOS)
      response = request_with_error_handling(req)

      validate_status!(response)
      protobuf_decode!(response.body, Bbs::Models::DesiredLRPSchedulingInfosResponse)
    end

    def actual_lrps_by_process_guid(process_guid)
      req = post_request(body: protobuf_encode!({ process_guid: process_guid }, Bbs::Models::ActualLRPsRequest), path: Routes::ACTUAL_LRPS)
      response = request_with_error_handling(req)

      validate_status!(response)
      protobuf_decode!(response.body, Bbs::Models::ActualLRPsResponse)
    end

    def request_with_error_handling(req)
      attempt ||= 1
      puts("#{Thread.current.object_id}: Attempt #{attempt} - #{bbs_ip}")
      # http_client.ipaddr = bbs_ip # tell the HTTP client which exact IP to target
      http_client.post(req.path, req.body, {'Content-Type'.freeze => 'application/x-protobuf'.freeze})
    rescue Resolv::ResolvError, Resolv::ResolvTimeout => e
      raise DnsResolutionError.new("dns resolution failed for #{bbs_url.host}: #{e.message}")
    rescue => e
      puts("#{Thread.current.object_id}: resuce 2")
      eliminated_ip = ips_remaining.shift
      logger.debug("attempt #{attempt} of 3: failed to reach the active bbs server on #{eliminated_ip}, removing from list")
      retry unless ips_remaining.empty? && (attempt += 1) > 3
      raise RequestError.new(e.message)
    end

    def bbs_ip
      self.ips_remaining = bbs_ip_addresses if ips_remaining.nil? || ips_remaining.empty?
      ips_remaining.first
    end

    private

    attr_reader :http_client, :bbs_url
    attr_accessor :ips_remaining

    def logger
      @logger ||= Steno.logger('cc.diego.client')
    end

    def protobuf_encode!(hash, protobuf_message_class)
      # See below link to understand proto3 message encoding
      # https://developers.google.com/protocol-buffers/docs/reference/ruby-generated#message
      protobuf_message_class.encode(protobuf_message_class.new(hash))
    rescue => e
      raise EncodeError.new(e.message)
    end

    def post_request(body: nil, path:)
      req = Net::HTTP::Post.new(path)
      req.body = body if body
      req['Content-Type'.freeze] = 'application/x-protobuf'.freeze
      req
    end

    def validate_status!(response)
      raise ResponseError.new("failed with status: #{response.code}, body: #{response.body}") unless response.code == '200'
    end

    def protobuf_decode!(message, protobuf_decoder)
      protobuf_decoder.decode(message)
    rescue => e
      raise DecodeError.new(e.message)
    end

    def bbs_ip_addresses
      Resolv.getaddresses(bbs_url.host).dup
    end

    def new_http_client(ca_cert_file, client_cert_file, client_key_file,
      connect_timeout, send_timeout, receive_timeout)
      client = Net::HTTP::Persistent.new()
      # client.use_ssl = false
      # client.verify_mode = OpenSSL::SSL::VERIFY_PEER
      # client.key = OpenSSL::PKey::RSA.new(File.read(client_key_file))
      # client.cert = OpenSSL::X509::Certificate.new(File.read(client_cert_file))
      # client.ca_file = ca_cert_file
      client.open_timeout = connect_timeout
      client.read_timeout = receive_timeout
      client.write_timeout = send_timeout
      # client.keep_alive_timeout = 10
      client
    end

    def get_url()
      bbs_url
    end
    def faraday(ca_cert_file, client_cert_file, client_key_file, connect_timeout, send_timeout, receive_timeout)
      conn = Faraday.new(url: get_url)
      conn
    end

  end
end
