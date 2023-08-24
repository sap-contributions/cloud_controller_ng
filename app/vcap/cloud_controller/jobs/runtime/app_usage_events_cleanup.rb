require 'vcap/cloud_controller/repositories/app_usage_event_repository'

module VCAP::CloudController
  module Jobs
    module Runtime
      class AppUsageEventsCleanup < VCAP::CloudController::Jobs::CCJob
        attr_accessor :cutoff_age_in_days

        def initialize(cutoff_age_in_days)
          @cutoff_age_in_days = cutoff_age_in_days
        end

        def perform
          logger = Steno.logger('cc.background')
          logger.info('Cleaning up old AppUsageEvent rows')

          repository = Repositories::AppUsageEventRepository.new
          repository.delete_events_older_than(cutoff_age_in_days)
        end

        def job_name_in_configuration
          :app_usage_events_cleanup
        end

        def max_attempts
          1
        end
      end
    end
  end
end
