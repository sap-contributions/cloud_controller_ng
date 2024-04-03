require 'cloud_controller/diego/staging_completion_handler'
require 'utils/uri_utils'

module VCAP::CloudController
  module Diego
    module CNB
      class StagingCompletionHandler < VCAP::CloudController::Diego::StagingCompletionHandler
        def logger_prefix
          'diego.staging.buildpack.'
        end

        def self.schema
          lambda { |_dsl|
            {
              result: {
                execution_metadata: String,
                lifecycle_type: Lifecycles::CNB,
                lifecycle_metadata: {
                  optional(:buildpacks) => [
                    {
                      optional(:key) => String,
                      optional(:name) => String,
                      optional(:version) => String
                    }
                  ]
                },
                process_types: dict(Symbol, String)
              }
            }
          }
        end

        private

        def handle_missing_droplet!(_payload)
          build.fail_to_stage!(nil, 'no droplet')
        end

        def save_staging_result(payload)
          lifecycle_data = payload[:result][:lifecycle_metadata]

          droplet.class.db.transaction do
            droplet.lock!
            build.lock!

            # TODO: What if lifecycle_data[:buildpacks] is nil?  Delete current buildpacks?
            # if lifecycle_data[:buildpacks]
            #   droplet.cnb_lifecycle_data.buildpacks = lifecycle_data[:buildpacks]
            #   droplet.cnb_lifecycle_data.save_changes(raise_on_save_failure: true)
            # end
            # droplet.save_changes(raise_on_save_failure: true)
            # build.droplet.reload

            droplet.process_types = payload[:result][:process_types]
            droplet.execution_metadata = payload[:result][:execution_metadata]
            droplet.mark_as_staged
            build.mark_as_staged
            build.save_changes(raise_on_save_failure: true)
            droplet.save_changes(raise_on_save_failure: true)
          end
        end
      end
    end
  end
end
