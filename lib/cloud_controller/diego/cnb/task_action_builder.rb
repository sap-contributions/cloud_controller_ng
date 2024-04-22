require 'diego/action_builder'
require 'cloud_controller/diego/task_environment_variable_collector'
require 'credhub/config_helpers'

module VCAP::CloudController
  module Diego
    module CNB
      class TaskActionBuilder
        def initialize(config, task, lifecycle_data)
          @task = task
          @lifecycle_data = lifecycle_data
          @config = config
        end

        def action
          launcher_args = ['app', task.command, '{}']

          ::Diego::ActionBuilder.action(
            ::Diego::Bbs::Models::RunAction.new(
              user: 'root',
              path: '/tmp/lifecycle/launcher',
              args: launcher_args,
              log_source: "APP/TASK/#{task.name}",
              resource_limits: ::Diego::Bbs::Models::ResourceLimits.new,
              env: task_environment_variables
            )
          )
        end

        def image_layers
          return [] unless @config.get(:diego, :enable_declarative_asset_downloads)

          [::Diego::Bbs::Models::ImageLayer.new(
            name: "cnb-#{lifecycle_stack}-lifecycle",
            url: LifecycleBundleUriGenerator.uri(config.get(:diego, :lifecycle_bundles)[lifecycle_bundle_key]),
            destination_path: '/tmp/lifecycle',
            layer_type: ::Diego::Bbs::Models::ImageLayer::Type::SHARED,
            media_type: ::Diego::Bbs::Models::ImageLayer::MediaType::TGZ
          )]
        end

        def task_environment_variables
          TaskEnvironmentVariableCollector.for_task task
        end

        def stack
          @stack ||= Stack.find(name: lifecycle_stack)
          raise CloudController::Errors::ApiError.new_from_details('StackNotFound', lifecycle_stack) unless @stack

          "preloaded:#{@stack.run_rootfs_image}"
        end

        def lifecycle_bundle_key
          :"cnb/#{lifecycle_stack}"
        end

        def cached_dependencies
          return nil if @config.get(:diego, :enable_declarative_asset_downloads)

          bundle = config.get(:diego, :lifecycle_bundles)[lifecycle_bundle_key]
          [::Diego::Bbs::Models::CachedDependency.new(
            from: LifecycleBundleUriGenerator.uri(bundle),
            to: '/tmp/lifecycle',
            cache_key: "cnb-#{lifecycle_stack}-lifecycle"
          )]
        end

        private

        def lifecycle_stack
          lifecycle_data[:stack]
        end

        attr_reader :config, :task, :lifecycle_data
      end
    end
  end
end
