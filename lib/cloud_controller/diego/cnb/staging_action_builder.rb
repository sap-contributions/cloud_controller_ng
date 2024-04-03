require 'credhub/config_helpers'
require 'diego/action_builder'
require 'digest/xxhash'

module VCAP::CloudController
  module Diego
    module CNB
      class StagingActionBuilder
        include ::Credhub::ConfigHelpers
        include ::Diego::ActionBuilder

        attr_reader :config, :lifecycle_data, :staging_details

        def initialize(config, staging_details, lifecycle_data)
          @config          = config
          @staging_details = staging_details
          @lifecycle_data  = lifecycle_data
        end

        def action
          actions = [
            stage_action,
            emit_progress(
              parallel(upload_actions),
              start_message: 'Uploading droplet, build artifacts cache...',
              success_message: 'Uploading complete',
              failure_message_prefix: 'Uploading failed'
            )
          ]

          actions.prepend(parallel(download_actions)) unless download_actions.empty?

          serial(actions)
        end

        def image_layers
          return [] unless @config.get(:diego, :enable_declarative_asset_downloads)

          layers = [
            # Type is shared, could be converted to CachedDependency
            ::Diego::Bbs::Models::ImageLayer.new(
              name: 'custom cnb lifecycle',
              from: 'https://storage.googleapis.com/cf-packages-public/lifecycle.tgz',
              destination_path: '/tmp/lifecycle',
              layer_type: ::Diego::Bbs::Models::ImageLayer::Type::SHARED,
              media_type: ::Diego::Bbs::Models::ImageLayer::MediaType::TGZ
            )
          ]

          if lifecycle_data[:app_bits_checksum][:type] == 'sha256'
            # Type is exclusive, will be converted to DownloadActions
            layers << ::Diego::Bbs::Models::ImageLayer.new({
              name: 'app package',
              url: lifecycle_data[:app_bits_download_uri],
              destination_path: '/home/vcap/workspace',
              layer_type: ::Diego::Bbs::Models::ImageLayer::Type::EXCLUSIVE,
              media_type: ::Diego::Bbs::Models::ImageLayer::MediaType::ZIP,
              digest_algorithm: ::Diego::Bbs::Models::ImageLayer::DigestAlgorithm::SHA256,
              digest_value: lifecycle_data[:app_bits_checksum][:value]
            }.compact)
          end

          if lifecycle_data[:build_artifacts_cache_download_uri] && lifecycle_data[:buildpack_cache_checksum].present?
            # Type is exclusive, will be converted to DownloadActions
            layers << ::Diego::Bbs::Models::ImageLayer.new({
              name: 'build artifacts cache',
              url: lifecycle_data[:build_artifacts_cache_download_uri],
              destination_path: '/tmp/cache',
              layer_type: ::Diego::Bbs::Models::ImageLayer::Type::EXCLUSIVE,
              media_type: ::Diego::Bbs::Models::ImageLayer::MediaType::ZIP,
              digest_algorithm: ::Diego::Bbs::Models::ImageLayer::DigestAlgorithm::SHA256,
              digest_value: lifecycle_data[:buildpack_cache_checksum]
            }.compact)
          end
        end

        def cached_dependencies
          return nil if @config.get(:diego, :enable_declarative_asset_downloads)

          [
            ::Diego::Bbs::Models::CachedDependency.new(
              # TODO: Get this thing from the platform or something?
              # from: LifecycleBundleUriGenerator.uri(config.get(:diego, :lifecycle_bundles)[lifecycle_bundle_key]),
              from: 'https://storage.googleapis.com/cf-packages-public/lifecycle.tgz',
              to: '/tmp/lifecycle',
              cache_key: 'cnb-lifecycle',
              name: 'custom cnb lifecycle'
            )
          ]
        end

        def stack
          @stack ||= Stack.find(name: lifecycle_stack)
          raise CloudController::Errors::ApiError.new_from_details('StackNotFound', lifecycle_stack) unless @stack

          "preloaded:#{@stack.build_rootfs_image}"
        end

        def task_environment_variables
          [
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'CNB_USER_ID', value: '2000'),
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'CNB_GROUP_ID', value: '2000')
          ]
        end

        private

        def download_actions
          result = []

          unless @config.get(:diego, :enable_declarative_asset_downloads) && lifecycle_data[:app_bits_checksum][:type] == 'sha256'
            result << ::Diego::Bbs::Models::DownloadAction.new({
              artifact: 'app package',
              from: lifecycle_data[:app_bits_download_uri],
              to: '/home/vcap/workspace',
              user: 'vcap',
              checksum_algorithm: lifecycle_data[:app_bits_checksum][:type],
              checksum_value: lifecycle_data[:app_bits_checksum][:value]
            }.compact)
          end

          if !@config.get(:diego,
                          :enable_declarative_asset_downloads) && (lifecycle_data[:build_artifacts_cache_download_uri] && lifecycle_data[:buildpack_cache_checksum].present?)
            result << try_action(::Diego::Bbs::Models::DownloadAction.new({
              artifact: 'build artifacts cache',
              from: lifecycle_data[:build_artifacts_cache_download_uri],
              to: '/tmp/cache',
              user: 'vcap',
              checksum_algorithm: 'sha256',
              checksum_value: lifecycle_data[:buildpack_cache_checksum]
            }.compact))
          end

          result
        end

        def stage_action
          ::Diego::Bbs::Models::RunAction.new(
            path: '/tmp/lifecycle/builder',
            user: 'vcap',
            args: lifecycle_data[:buildpacks].map do |buildpack|
              ['--buildpacks', buildpack[:url]]
            end.flatten
          )
        end

        def upload_actions
          [
            ::Diego::Bbs::Models::UploadAction.new(
              user: 'vcap',
              artifact: 'droplet',
              from: '/tmp/droplet',
              to: upload_droplet_uri.to_s
            )
          ]
        end

        def skip_detect?
          lifecycle_data[:buildpacks].any? { |buildpack| buildpack[:skip_detect] }
        end

        def lifecycle_stack
          lifecycle_data[:stack]
        end

        def lifecycle_bundle_key
          :"buildpack/#{lifecycle_stack}"
        end

        def upload_droplet_uri
          upload_droplet_uri       = URI(config.get(:diego, :cc_uploader_url))
          upload_droplet_uri.path  = "/v1/droplet/#{staging_details.staging_guid}"
          upload_droplet_uri.query = {
            'cc-droplet-upload-uri' => lifecycle_data[:droplet_upload_uri],
            'timeout' => config.get(:staging, :timeout_in_seconds)
          }.to_param
          upload_droplet_uri.to_s
        end
      end
    end
  end
end
