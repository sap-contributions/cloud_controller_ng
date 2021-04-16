require 'cloud_controller/adjective_noun_generator'
require 'securerandom'
require 'timeout'

PREFIX = 'perf'.freeze

module VCAP::CloudController
  module PerfDataSeeds
    class << self
      def write_seed_data(config)
        create_orgs config.fetch('orgs', 0)
        create_spaces config.fetch('spaces', 0)
        create_apps config.fetch('apps', 0)
        create_domains config.fetch('domains', 0)
        create_routes config.fetch('routes', 0)
        create_route_mappings config.fetch('route_mappings', 0)
        create_service_brokers config.fetch('service_brokers', 0)
        create_services config.fetch('service_offerings', 0)
        create_service_plans config.fetch('service_plans', 0)
        create_service_instances config.fetch('managed_service_instances', 0), managed: true
        create_service_instances config.fetch('user_provided_service_instances', 0), managed: false
        create_service_plan_visibilities config.fetch('service_plan_visibilities', 0), config.fetch('orgs', 0)
        create_service_bindings config.fetch('service_bindings', 0)
        create_security_groups config.fetch('security_groups', 0)
        create_security_group_spaces config.fetch('security_group_spaces', 0)
      end

      def create_orgs(num_orgs)
        puts "Creating #{num_orgs} orgs"
        orgs = num_orgs.times.map do |i|
          org_uuid = SecureRandom.uuid
          Organization.new(name: "#{PREFIX}-org-#{org_uuid}", guid: org_uuid, quota_definition_id: 1)
        end
        Organization.multi_insert(orgs)
      end

      def create_spaces(num_spaces)
        puts "Creating #{num_spaces} spaces"
        orgs = Organization.all
        spaces = num_spaces.times.map do |i|
          space_uuid = SecureRandom.uuid
          Space.new(name: "#{PREFIX}-space-#{space_uuid}", organization: orgs.sample, guid: space_uuid)
        end
        Space.multi_insert(spaces)
      end

      def create_apps(num_apps)
        puts "Creating #{num_apps} apps"
        spaces = Space.all
        apps = num_apps.times.map do |i|
          uuid = SecureRandom.uuid
          AppModel.new(name: "#{PREFIX}-app-#{uuid}", space: spaces.sample, guid: uuid)
        end
        AppModel.multi_insert(apps)
      end

      def create_domains(num)
        puts "Creating #{num} domains"
        orgs = Organization.select_map(:id)
        domains = num.times.map do |i|
          uuid = SecureRandom.uuid
          Domain.new(name: "#{PREFIX}-domain-#{uuid}", wildcard: Random.rand < 0.2, guid: uuid, owning_organization_id: Random.rand < 0.1 ? nil : orgs.sample)
        end
        Domain.multi_insert(domains)
      end

      def create_routes(num)
        puts "Creating #{num} routes"
        spaces = Space.select_map(:id)
        domains = Domain.select_map(:id)
        routes = num.times.map do |i|
          uuid = SecureRandom.uuid
          Route.new(host: "#{PREFIX}-route-#{uuid}", guid: uuid, space_id: spaces.sample, domain_id: domains.sample)
        end
        Route.multi_insert(routes)
      end

      def create_route_mappings(num)
        puts "Creating #{num} route mappings"
        space_guids = Space.select_map(:guid)
        routes = Route.all
        apps = AppModel.all
        route_mappings = num.times.map do |i|
          space_guid = space_guids.sample
          space_apps = apps.select { |a| a.space_guid == space_guid }
          space_routes = routes.select { |r| r.space_guid == space_guid }
          redo if space_apps.empty? || space_routes.empty?
          RouteMappingModel.new(
            guid: SecureRandom.uuid,
            app: space_apps.sample,
            route: space_routes.sample
          )
        end
        RouteMappingModel.multi_insert(route_mappings)
      end

      def create_service_brokers(num_service_brokers)
        puts "Creating #{num_service_brokers} service brokers"
        brokers = num_service_brokers.times.map do |i|
          service_broker_uuid = SecureRandom.uuid
          ServiceBroker.new(name: "#{PREFIX}-service-broker-#{service_broker_uuid}", broker_url: 'https://vcap.me',
            auth_username: 'user', auth_password: 'pass', guid: service_broker_uuid)
        end
        ServiceBroker.multi_insert(brokers)
      end

      def create_services(num_services)
        puts "Creating #{num_services} service offerings"
        all_brokers = ServiceBroker.all
        services = num_services.times.map do |i|
          service_guid = SecureRandom.uuid
          Service.new(label: "#{PREFIX}-service-#{service_guid}", description: "service #{service_guid}",
            bindable: [true, false].sample, service_broker_id: all_brokers.sample.id, guid: service_guid)
        end
        Service.multi_insert(services)
      end

      def create_service_plans(num_service_plans)
        puts "Creating #{num_service_plans} service plans"
        all_services = Service.all
        service_plans = num_service_plans.times.map do |j|
          service = all_services.sample
          service_plan_uuid = SecureRandom.uuid
          ServicePlan.new(name: "#{PREFIX}-service-plan-#{service.guid}-#{service_plan_uuid}", service: service, description: "service plan for service #{service.guid}",
            free: [true, false].sample, public: [true, false].sample, guid: service_plan_uuid, unique_id: service_plan_uuid)
        end
        ServicePlan.multi_insert(service_plans)
      end

      def create_service_instances(num_service_instances, managed: true)
        puts "Creating #{num_service_instances} #{managed ? 'managed' : 'user provided'} service instances"
        all_service_plans = ServicePlan.all
        all_spaces = Space.all
        managed_service_instances = num_service_instances.times.map do |i|
          ManagedServiceInstance.new(name: "#{PREFIX}-service-instance-#{SecureRandom.uuid}", space: all_spaces.sample, is_gateway_service: managed,
                                 service_plan_id: all_service_plans.sample.id)
        end
        ManagedServiceInstance.multi_insert(managed_service_instances)
      end

      def create_service_plan_visibilities(num_service_plan_visibilities, num_orgs)
        puts "Creating #{num_service_plan_visibilities} service plan visibilities"
        all_plans = ServicePlan.all
        service_plan_visibilities = Organization.map do |o|
          all_plans.sample((num_service_plan_visibilities / num_orgs).to_i).map do |p|
            ServicePlanVisibility.new(guid: SecureRandom.uuid, organization: o, service_plan: p)
          end
        end.flatten
        ServicePlanVisibility.multi_insert(service_plan_visibilities)
      end

      def create_service_bindings(num)
        puts "Creating #{num} service bindings"
        spaces = Space.all
        service_instances = ServiceInstance.all
        apps = AppModel.all
        bindings = num.times.map do |i|
          space = spaces.sample
          space_apps = apps.select { |a| a.space_guid == space.guid }
          space_service_instances = service_instances.select { |r| r.space_id == space.id }
          redo if space_apps.empty? || space_service_instances.empty?
          ServiceBinding.new(
            guid: SecureRandom.uuid,
            app: space_apps.sample,
            service_instance: space_service_instances.sample,
            credentials: '{}'
          )
        end
        ServiceBinding.multi_insert bindings
      end

      def create_security_groups(num_sgs)
        puts "Creating #{num_sgs} security groups"
        sgs = num_sgs.times.map do |i|
          uuid = SecureRandom.uuid
          SecurityGroup.new(name: "#{PREFIX}-security-group-#{uuid}", guid: uuid)
        end
        SecurityGroup.multi_insert(sgs)
      end

      def create_security_group_spaces(num_sgss)
        puts "Creating #{num_sgss} security group spaces"
        sgs = SecurityGroup.select_map(:id)
        spaces = Space.select_map(:id)
        sgss = num_sgss.times.map do |i|
          SecurityGroupsSpace.new(space_id: spaces.sample, security_group_id: sgs.sample)
        end
        SecurityGroupsSpace.multi_insert sgss
      end
    end
  end
end
