module CloudFoundry
  module Middleware
    module UserResetInterval
      def next_reset_interval(user_guid, reset_interval_in_minutes)
        user_digest = Digest::MD5.hexdigest(user_guid || '')[..5].to_i(16)
        # Use user_digest to return offset between 0.0 and 1.0 times the reset_interval
        offset = (user_digest.to_f / 16.pow(6) * reset_interval_in_minutes.minutes.to_i).round.seconds

        no_of_intervals = ((Time.now.utc - offset).to_f / reset_interval_in_minutes.minutes.to_i).floor + 1

        Time.at(offset + (no_of_intervals * reset_interval_in_minutes.minutes.to_i)).utc
      end
    end
  end
end
