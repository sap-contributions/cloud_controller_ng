require 'concurrent-ruby'

module CloudFoundry
  module Middleware
    class RequestCounter
      include Singleton

      def initialize
        @data = {}
      end

      def limit=(limit)
        @limit = limit
      end

      def try_acquire?(user_guid)
        @data[user_guid] = Concurrent::Semaphore.new(@limit) unless @data.key?(user_guid)
        @data[user_guid].try_acquire
      end

      def release(user_guid)
        @data[user_guid].release if @data.key?(user_guid)
      end
    end

    class RateLimiter
      def initialize(app, opts)
        @app                               = app
        @logger                            = opts[:logger]
        @request_counter = RequestCounter.instance
      end

      def call(env)        
        @logger.info("dizzz izzz zuper coooooool")
        request = ActionDispatch::Request.new(env)
        user_guid = env['cf.user_guid']

        return too_many_requests!(env, user_guid) unless @request_counter.try_acquire?(user_guid)

        begin
          return @app.call(env)
        rescue => e
          raise e
        ensure
          @request_counter.release(user_guid)
        end


        @app.call(env)
      end

      private

      def admin?
        VCAP::CloudController::SecurityContext.admin? || VCAP::CloudController::SecurityContext.admin_read_only?
      end

      def user_token?(env)
        !!env['cf.user_guid']
      end

      def too_many_requests!(env, user_guid)
        rate_limit_headers = {}
        @logger.info("Concurrent rate limit exceeded for user '#{user_guid}'")
        message = rate_limit_error(env).to_json
        [429, rate_limit_headers, [message]]
      end

      def rate_limit_error(env)
        error_name = 'RateLimitExceeded'
        api_error = CloudController::Errors::ApiError.new_from_details(error_name)
        version   = env['PATH_INFO'][0..2]
        if version == '/v2'
          ErrorPresenter.new(api_error, Rails.env.test?, V2ErrorHasher.new(api_error)).to_hash
        elsif version == '/v3'
          ErrorPresenter.new(api_error, Rails.env.test?, V3ErrorHasher.new(api_error)).to_hash
        end
      end
    end
  end
end
