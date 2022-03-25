require 'spec_helper'

RSpec::Matchers.define :be_an_empty_deserialized_error do
  match do |object|
    if Rails::VERSION::MAJOR > 5
      num_errors = object.errors.length
    else
      num_errors = object.messages.length
    end
    expect(num_errors).to eq(0)
  end
end

RSpec::Matchers.define :be_a_deserialized_error_with_four_messages do
  match do |object|
    if Rails::VERSION::MAJOR > 5
      errors = {}
      object.errors.each do |e|
        errors[e.attribute] = Array.wrap(errors[e.attribute]).concat(Array.wrap(e.options[:message]))
      end
    else
      errors = object.messages
    end
    expect(errors).to eq({
      key1: %w[message1 message2],
      key2: %w[message3 message4]
    })
  end
end

module VCAP::CloudController
  RSpec.describe Jobs do
    context 'Jobs deserialization' do
      context 'ActiveModel::Errors v5' do
        context 'no messages' do
          let(:serialized_object) do
            <<~EOS
              --- !ruby/object:ActiveModel::Errors
              messages: {}
            EOS
          end

          it 'can be deserialized' do
            object = YAML.load_dj(serialized_object)
            expect(object).not_to be_nil
            expect(object).to be_an_empty_deserialized_error
          end
        end

        context 'four messages' do
          let(:serialized_object) do
            <<~EOS
              --- !ruby/object:ActiveModel::Errors
              messages:
                :key1:
                - message1
                - message2
                :key2:
                - message3
                - message4
            EOS
          end

          it 'can be deserialized' do
            object = YAML.load_dj(serialized_object)
            expect(object).not_to be_nil
            expect(object).to be_a_deserialized_error_with_four_messages
          end
        end
      end

      context 'ActiveModel::Errors v6' do
        context 'no messages' do
          let(:serialized_object) do
            <<~EOS
              --- !ruby/object:ActiveModel::Errors
              errors: []
            EOS
          end

          it 'can be deserialized' do
            object = YAML.load_dj(serialized_object)
            expect(object).not_to be_nil
            expect(object).to be_an_empty_deserialized_error
          end
        end

        context 'four messages' do
          let(:serialized_object) do
            <<~EOS
              --- !ruby/object:ActiveModel::Errors
              errors:
              - !ruby/object:ActiveModel::Error
                attribute: :key1
                raw_type: :invalid
                type: :invalid
                options:
                  :message: message1
              - !ruby/object:ActiveModel::Error
                attribute: :key1
                raw_type: :invalid
                type: :invalid
                options:
                  :message: message2
              - !ruby/object:ActiveModel::Error
                attribute: :key2
                raw_type: :invalid
                type: :invalid
                options:
                  :message: message3
              - !ruby/object:ActiveModel::Error
                attribute: :key2
                raw_type: :invalid
                type: :invalid
                options:
                  :message: message4
            EOS
          end

          it 'can be deserialized' do
            object = YAML.load_dj(serialized_object)
            expect(object).not_to be_nil
            expect(object).to be_a_deserialized_error_with_four_messages
          end
        end

        context 'SpaceApplyManifestActionJob' do
          let(:serialized_object) do
            space = VCAP::CloudController::Space.make

            <<~EOS
              --- !ruby/object:VCAP::CloudController::Jobs::LoggingContextJob
              handler: !ruby/object:VCAP::CloudController::Jobs::TimeoutJob
                handler: !ruby/object:VCAP::CloudController::Jobs::PollableJobWrapper
                  existing_guid:
                  handler: !ruby/object:VCAP::CloudController::Jobs::SpaceApplyManifestActionJob
                    space: !ruby/object:VCAP::CloudController::Space
                      values:
                        :id: #{space.id}
                        :guid: eaeb2718-1b6e-4407-a0e3-97c359fc5097
                        :created_at: 2020-05-27 20:28:51.134657000 Z
                        :updated_at: 2020-05-27 20:28:51.134657000 Z
                        :name: some-space
                        :organization_id: 1
                        :space_quota_definition_id:
                        :allow_ssh: true
                        :isolation_segment_guid:
                    app_guid_message_hash:
                      279c616d-2e8c-4cfa-9eca-bda9ec464740: &1 !ruby/object:VCAP::CloudController::AppManifestMessage
                        requested_keys:
                        - :name
                        - :disk_quota
                        - :instances
                        - :path
                        - :memory
                        - :default_route
                        - :buildpacks
                        - :routes
                        extra_keys:
                        - :path
                        buildpacks:
                        - binary_buildpack
                        disk_quota: 128M
                        instances: 1
                        memory: 128M
                        name: some-app
                        default_route: true
                        routes:
                        - :route: some-app.cf.some.domain
                        original_yaml:
                          name: some-app
                          disk-quota: 128M
                          instances: 1
                          path: \"/home/vcap/app/some-app\"
                          memory: 128M
                          default-route: true
                          buildpacks:
                          - binary_buildpack
                          routes:
                          - route: some-app.cf.some.domain
                        validation_context:
                        errors: !ruby/object:ActiveModel::Errors
                          base: *1
                          errors: []
                        manifest_process_scale_messages:
                        - &2 !ruby/object:VCAP::CloudController::ManifestProcessScaleMessage
                          requested_keys:
                          - :instances
                          - :memory
                          - :disk_quota
                          - :type
                          extra_keys: []
                          instances: 1
                          memory: 128
                          disk_quota: 128
                          type: web
                          validation_context:
                          errors: !ruby/object:ActiveModel::Errors
                            base: *2
                            errors: []
                        manifest_process_update_messages: []
                        app_update_message: &3 !ruby/object:VCAP::CloudController::AppUpdateMessage
                          requested_keys:
                          - :lifecycle
                          extra_keys: []
                          validation_context:
                          errors: !ruby/object:ActiveModel::Errors
                            base: *3
                            errors: []
                          lifecycle:
                            :data:
                              :buildpacks:
                              - binary_buildpack
                        manifest_routes_update_message: &4 !ruby/object:VCAP::CloudController::ManifestRoutesUpdateMessage
                          requested_keys:
                          - :routes
                          - :default_route
                          extra_keys: []
                          routes:
                          - :route: some-app.cf.some.domain
                          default_route: true
                          validation_context:
                          errors: !ruby/object:ActiveModel::Errors
                            base: *4
                            errors: []
                          manifest_route_mappings:
                          - :route: !ruby/object:VCAP::CloudController::ManifestRoute
                              attrs:
                                :scheme: unspecified
                                :user:
                                :password:
                                :host: some-app.cf.some.domain
                                :port:
                                :path: ''''
                                :query:
                                :fragment:
                                :full_route: some-app.cf.some.domain
                            :protocol:
                    apply_manifest_action: !ruby/object:VCAP::CloudController::AppApplyManifest
                      user_audit_info: !ruby/object:VCAP::CloudController::UserAuditInfo
                        user_email: some-user@some.domain
                        user_name: some-user@some.domain
                        user_guid: c46fef92-9e83-490b-a3e4-d99ed2020d45
                    user_audit_info: !ruby/object:VCAP::CloudController::UserAuditInfo
                      user_email: some-user@some.domain
                      user_name: some-user@some.domain
                      user_guid: c46fef92-9e83-490b-a3e4-d99ed2020d45
                timeout: 14400
              request_id: db48f117-cf9f-4aba-565c-dbf28e81bfac::1baf2cfa-ab16-4984-9c3a-e5b7dae5973b
            EOS
          end

          it 'can be deserialized' do
            object = YAML.load_dj(serialized_object)
            expect(object).not_to be_nil
          end
        end
      end
    end
  end
end
