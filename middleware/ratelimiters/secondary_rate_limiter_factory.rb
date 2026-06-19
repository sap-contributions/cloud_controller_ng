module CloudFoundry
  module Middleware
    module Ratelimiters
      class SecondaryRateLimiterFactory
        @mutex    = Mutex.new
        @instance = nil

        def self.instance(config, logger)
          return @instance if @instance

          @mutex.synchronize do
            @instance ||= build_strategy(config, logger)
          end
        end

        private_class_method def self.build_strategy(config, logger)
          strategy = config.get(:secondary_rate_limiter, :strategy)
          case strategy
          when 'concurrency-limiter'
            ConcurrencyLimiter.new(
              'rate-limit-secondary',
              config.get(:secondary_rate_limiter, :max_concurrent_requests),
              logger,
              redis_connection_pool_size: config.get(:secondary_rate_limiter, :redis_connection_pool_size),
              counter_ttl_seconds: config.get(:secondary_rate_limiter, :counter_ttl_seconds)
            )
          else
            raise "Unknown secondary rate limit strategy: #{strategy}"
          end
        end
      end
    end
  end
end
