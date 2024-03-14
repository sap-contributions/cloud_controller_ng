module CloudFoundry
  module Middleware
    class April1st
      def initialize(app)
        @app = app
      end

      def call(env)
        status, headers, body = @app.call(env)

        included_endpoints = %w[/v3/spaces /v3/organizations /v2/spaces /v2/organizations]

        if included_endpoints.any? { |ep| env['REQUEST_PATH'].include?(ep) } && is_cli?(env['HTTP_USER_AGENT']) && DateTime.now.utc.between?("2024-04-01 00:00:00", "2024-04-02 23:59:59")
          # Ensure existing warnings are appended by ',' (unicode %2C)
          new_warning = env['X-Cf-Warnings'].nil? ? escaped_warning : "#{env['X-Cf-Warnings']}%2C#{escaped_warning}"
          headers['X-Cf-Warnings'] = new_warning
        end

        [status, headers, body]
      end

      def escaped_warning
        CGI.escape("\u{1F6A7} \u{1F6A7} \u{1F6A7} We've updated our Terms and Conditions, effective April 1st \u{1F6A7} \u{1F6A7} \u{1F6A7}\nTo remain informed and continue using our services, please click [https://terms.cf.sap.hana.ondemand.com/] to read and accept the new terms.\n")
      end

      def is_cli?(user_agent_string)
        regex = %r{
            [cC][fF]      # match 'cf', case insensitive
            [^/]*        # match any characters that are not '/'
            /            # match '/' character
            (\d+\.\d+\.\d+)  # capture the version number (expecting 3 groups of digits separated by '.')
            (?:\+|\s)     # match '+' character or a whitespace, non-capturing group
          }x

        match = user_agent_string.match(regex)
        return false if match.nil?

        true
      rescue StandardError => e
        logger.warn("Warning: An error occurred while checking user agent version: #{e.message}")
        false
      end

      private

      def logger
        @logger = Steno.logger('cc.april1st')
      end
    end
  end
end
