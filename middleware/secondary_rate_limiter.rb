require 'mixins/client_ip'

module CloudFoundry
  module Middleware
    class SecondaryRateLimiter
      include CloudFoundry::Middleware::ClientIp

      def initialize(app, opts)
        @app = app
        @logger = opts[:logger]
        @rate_limiter_strategy = opts[:rate_limiter_strategy]
        @header_suffix = @rate_limiter_strategy.header_suffix
      end

      def call(env)
        rate_limit_headers = RateLimitHeaders.new(@header_suffix)
        user_guid = nil
        incremented = false

        if apply_rate_limiting?(env)
          user_guid = get_user_id(env)
          incremented = @rate_limiter_strategy.try_increment?(user_guid, rate_limit_headers)
          return too_many_requests!(env, user_guid, rate_limit_headers) unless incremented
        end

        status, headers, body = @app.call(env)
        [status, headers.merge(rate_limit_headers.to_hash), body]
      ensure
        @rate_limiter_strategy.decrement(user_guid) if incremented
      end

      private

      def get_user_id(env)
        user_token?(env) ? env['cf.user_guid'] : client_ip(ActionDispatch::Request.new(env))
      end

      def user_token?(env)
        !!env['cf.user_guid']
      end

      def too_many_requests!(env, user_guid, rate_limit_headers)
        @logger.info("Secondary rate limit exceeded for user '#{user_guid}' " \
                     "path=#{env['PATH_INFO']} limit=#{rate_limit_headers.limit} remaining=#{rate_limit_headers.remaining}")
        headers = rate_limit_headers.to_hash
        headers["Retry-After-#{@header_suffix}"] = @rate_limiter_strategy.suggested_retry_after.to_s
        headers['Content-Type'] = 'text/plain; charset=utf-8'
        message = rate_limit_error(env).to_json
        headers['Content-Length'] = message.length.to_s
        [429, headers, [message]]
      end

      def apply_rate_limiting?(env)
        request = ActionDispatch::Request.new(env)
        !basic_auth?(env) && !internal_api?(request) && !root_api?(request) && !admin?
      end

      def root_api?(request)
        request.fullpath.match(%r{\A(?:/v2/info|/v3|/|/healthz)\z})
      end

      def internal_api?(request)
        request.fullpath.match(%r{\A/internal})
      end

      def basic_auth?(env)
        auth = Rack::Auth::Basic::Request.new(env)
        auth.provided? && auth.basic?
      end

      def admin?
        VCAP::CloudController::SecurityContext.admin? || VCAP::CloudController::SecurityContext.admin_read_only?
      end

      def rate_limit_error(env)
        error_name = user_token?(env) ? @rate_limiter_strategy.error_name : @rate_limiter_strategy.error_name_ip_based
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
