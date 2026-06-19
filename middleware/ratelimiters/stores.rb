module CloudFoundry
  module Middleware
    module Ratelimiters
      class StoreError < StandardError; end

      class RedisStore
        def initialize(redis, counter_ttl_seconds)
          @redis = redis
          @counter_ttl_seconds = counter_ttl_seconds
        end

        def self.new_socket(socket, connection_pool_size, counter_ttl_seconds)
          connection_pool_size ||= VCAP::CloudController::Config.config.get(:puma, :max_threads) || 1
          redis = ConnectionPool::Wrapper.new(size: connection_pool_size) do
            Redis.new(timeout: 1, path: socket)
          end
          new(redis, counter_ttl_seconds)
        end

        def self.new_tcp(host, port, connection_pool_size, counter_ttl_seconds)
          connection_pool_size ||= VCAP::CloudController::Config.config.get(:puma, :max_threads) || 1
          redis = ConnectionPool::Wrapper.new(size: connection_pool_size) do
            Redis.new(timeout: 1, host: host, port: port)
          end
          new(redis, counter_ttl_seconds)
        end

        def increment(key, logger)
          count = @redis.incr(key).to_i
          @redis.expire(key, @counter_ttl_seconds) if count == 1 && @counter_ttl_seconds
          count
        rescue Redis::BaseError => e
          logger.error("Redis error: #{e.class} - #{e.message}")
          raise StoreError.new("increment failed: #{e.message}")
        end

        def decrement(key, logger)
          count = @redis.decr(key).to_i
          @redis.incr(key) if count < 0
          [count, 0].max
        rescue Redis::BaseError => e
          logger.error("Redis error: #{e.class} - #{e.message}")
          raise StoreError.new("decrement failed: #{e.message}")
        end
      end
      class InMemoryStore
        def initialize
          raise 'not implemented yet'
        end
      end
    end
  end
end
