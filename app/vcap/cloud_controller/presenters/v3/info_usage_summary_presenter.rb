require 'presenters/v3/base_presenter'
require 'vcap/cloud_controller/presenters/mixins/metadata_presentation_helpers'
require 'vcap/cloud_controller/presenters/helpers/censorship'

module VCAP::CloudController::Presenters::V3
  class InfoUsageSummaryPresenter < BasePresenter
    def to_hash
      {
        usage_summary: {
          started_instances: usage_summary.started_instances,
          memory_in_mb: usage_summary.memory_in_mb
        },
        links: {
          self: { href: build_self }
        }
      }
    end

    private

    def usage_summary
      @resource
    end

    def build_self
      url_builder.build_url(path: '/v3/info/usage_summary')
    end
  end
end
