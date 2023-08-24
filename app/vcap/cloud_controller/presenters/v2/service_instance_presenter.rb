require 'vcap/cloud_controller/presenters/v2/base_presenter'
require 'vcap/cloud_controller/presenters/v2/presenter_provider'
require 'vcap/cloud_controller/presenters/mixins/services_presentation_helpers'

module CloudController
  module Presenters
    module V2
      class ServiceInstancePresenter < BasePresenter
        extend PresenterProvider
        include VCAP::CloudController::Presenters::Mixins::ServicesPresentationHelpers

        present_for_class 'VCAP::CloudController::ServiceInstance'
        present_for_class 'VCAP::CloudController::ManagedServiceInstance'
        present_for_class 'VCAP::CloudController::UserProvidedServiceInstance'

        def entity_hash(controller, obj, opts, depth, parents, orphans=nil)
          export_attrs = opts.delete(:export_attrs) if depth == 0

          rel_hash = RelationsPresenter.new.to_hash(controller, obj, opts, depth, parents, orphans)
          obj_hash = obj.to_hash(attrs: export_attrs)

          if obj.export_attrs_from_methods
            obj.export_attrs_from_methods.each do |key, meth|
              obj_hash[key.to_s] = obj.send(meth)
            end
          end

          if managed_service_instance(obj)
            # TODO: add eager loading to other endpoints and remove this database query
            service_plan = obj.service_plan || VCAP::CloudController::ServicePlan.find(id: obj.service_plan_id)
            obj_hash['maintenance_info'] = parse_maintenance_info(obj.maintenance_info)
            obj_hash['service_plan_guid'] = service_plan.guid
            obj_hash['service_guid'] = service_plan.service.guid
            rel_hash['service_url'] = "/v2/services/#{service_plan.service.guid}"
            rel_hash['shared_from_url'] = "/v2/service_instances/#{obj.guid}/shared_from"
            rel_hash['shared_to_url'] = "/v2/service_instances/#{obj.guid}/shared_to"
            rel_hash['service_instance_parameters_url'] = "/v2/service_instances/#{obj.guid}/parameters"
          end

          obj_hash.merge!(rel_hash)
        end

        private

        def managed_service_instance(service_instance)
          service_instance.service_plan_id
        end
      end
    end
  end
end
