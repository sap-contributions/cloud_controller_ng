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
        create_users config.fetch('users', 0)
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
        create_events config.fetch('events', 0)
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

      def create_users(num)
        puts "Creating #{num} users"
        users = num.times.map do |i|
          User.new(guid: SecureRandom.uuid)
        end
        User.multi_insert(users)
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
        routes = Route.all.group_by(&:space_guid)
        apps = AppModel.all.group_by(&:space_guid)
        route_mappings = num.times.map do |i|
          space_guid = space_guids.sample
          redo if !apps.key?(space_guid) || !routes.key?(space_guid)
          RouteMappingModel.new(
            guid: SecureRandom.uuid,
            app: apps[space_guid].sample,
            route: routes[space_guid].sample
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
        return unless num_service_plan_visibilities > 0

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
        service_instances = ServiceInstance.all.group_by(&:space_id)
        apps = AppModel.all.group_by(&:space_guid)
        existing_bindings = Hash.new []
        bindings = num.times.map do |i|
          space = spaces.sample
          app = apps.fetch(space.guid, []).sample
          service_instance = service_instances.fetch(space.id, []).sample
          redo if app.nil? || service_instance.nil?
          redo if existing_bindings.fetch(app.guid, []).include? service_instance.guid
          existing_bindings[app.guid] += [service_instance.guid]
          ServiceBinding.new(
            guid: SecureRandom.uuid,
            app: app,
            service_instance: service_instance,
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

      def create_events(num)
        puts "Creating #{num} events"
        event_types = %w(app.crash audit.app.apply_manifest audit.app.build.create audit.app.create audit.app.delete-request
                         audit.app.deployment.cancel audit.app.deployment.create audit.app.droplet.create audit.app.droplet.delete
                         audit.app.droplet.mapped audit.app.environment.show audit.app.map-route audit.app.package.create audit.app.package.delete
                         audit.app.package.download audit.app.package.upload audit.app.process.crash audit.app.process.create audit.app.process.delete
                         audit.app.process.scale audit.app.process.terminate_instance audit.app.process.update audit.app.restage audit.app.restart
                         audit.app.revision.create audit.app.ssh-authorized audit.app.ssh-unauthorized audit.app.start audit.app.stop audit.app.task.cancel
                         audit.app.task.create audit.app.unmap-route audit.app.update audit.app.upload-bits audit.organization.create
                         audit.organization.delete-request audit.organization.update audit.route.create audit.route.delete-request audit.route.update
                         audit.service_binding.create audit.service_binding.delete audit.service_binding.start_create audit.service_binding.start_delete
                         audit.service_broker.create audit.service_broker.delete audit.service_broker.update audit.service.create audit.service.delete
                         audit.service_instance.create audit.service_instance.delete audit.service_instance.purge audit.service_instance.start_create
                         audit.service_instance.start_delete audit.service_instance.start_update audit.service_instance.unbind_route audit.service_instance.update
                         audit.service_key.create audit.service_key.delete audit.service_plan.create audit.service_plan.delete audit.service_plan.update
                         audit.service_plan_visibility.create audit.service_plan_visibility.delete audit.service_plan_visibility.update
                         audit.service_route_binding.create audit.service.update audit.space.create audit.space.delete-request audit.space.update
                         audit.user.organization_auditor_add audit.user.organization_auditor_remove audit.user.organization_manager_add
                         audit.user.organization_manager_remove audit.user.organization_user_add audit.user.organization_user_remove
                         audit.user_provided_service_instance.create audit.user_provided_service_instance.delete audit.user_provided_service_instance.update
                         audit.user.space_auditor_add audit.user.space_auditor_remove audit.user.space_developer_add audit.user.space_developer_remove
                         audit.user.space_manager_add audit.user.space_manager_remove blob.remove_orphan)
        spaces = Space.select_map(:guid)
        orgs = Organization.select_map(:guid)
        apps = AppModel.all
        users = User.all
        num.times.each_slice(100_000) do |chunk|
          events = chunk.map do |i|
            if Random.rand < 0.5
              app = apps.sample
              actee_guid = app.guid
              actee_type = 'app'
              actee_name = app.name
            else
              user = users.sample
              actee_guid = user.guid
              actee_type = 'user'
              actee_name = user.username
            end
            actor = users.sample
            Event.new(
              guid: SecureRandom.uuid,
              space_guid: spaces.sample,
              organization_guid: orgs.sample,
              type: event_types.sample,
              timestamp: Sequel::CURRENT_TIMESTAMP,
              actee: actee_guid,
              actee_type: actee_type,
              actee_name: actee_name,
              actor: actor.guid,
              actor_type: 'user',
              actor_name: actor.username,
              actor_username: actor.username,
            )
          end
          Event.multi_insert events
        end
      end
    end
  end
end
