require_relative 'stores'

module CloudFoundry
  module Middleware
    module Ratelimiters
      class ConcurrencyLimiter
        def initialize(key_prefix, max_concurrent_requests, logger, redis_connection_pool_size: nil, counter_ttl_seconds: nil)
          @max_concurrent_requests = max_concurrent_requests
          @key_prefix = key_prefix
          @redis_connection_pool_size = redis_connection_pool_size
          @counter_ttl_seconds = counter_ttl_seconds
          @logger = logger
        end

        def try_increment?(user_guid, rate_limit_headers)
          key = "#{@key_prefix}:#{user_guid}"
          count = store.increment(key, @logger)
          if count <= @max_concurrent_requests
            rate_limit_headers.limit = @max_concurrent_requests.to_s
            rate_limit_headers.remaining = (@max_concurrent_requests - count).to_s
            return true
          end
          store.decrement(key, @logger)
          rate_limit_headers.limit = @max_concurrent_requests.to_s
          rate_limit_headers.remaining = '0'
          false
        rescue StoreError
          # fail open
          true
        end

        def decrement(user_guid)
          key = "#{@key_prefix}:#{user_guid}"
          store.decrement(key, @logger)
        rescue StoreError
          # fail open
        end

        def suggested_retry_after
          # TODO: find better estimation
          1
        end

        def error_name
          'ConcurrentRequestLimitExceeded'
        end

        def error_name_ip_based
          'IPBasedConcurrentRequestLimitExceeded'
        end

        def header_suffix
          'Concurrent'
        end

        private

        def store
          return @store if defined?(@store)

          redis_socket = VCAP::CloudController::Config.config.get(:redis, :socket)
          redis_host   = VCAP::CloudController::Config.config.get(:redis, :host)
          redis_port   = VCAP::CloudController::Config.config.get(:redis, :port)
          @store = if redis_socket.present?
                     RedisStore.new_socket(redis_socket, @redis_connection_pool_size, @counter_ttl_seconds)
                   elsif redis_host.present?
                     RedisStore.new_tcp(redis_host, redis_port || 6379, @redis_connection_pool_size, @counter_ttl_seconds)
                   else
                     InMemoryStore.new
                   end
        end
      end
    end
  end
end
