require 'support/compatibility/accessed_model_columns_plugin'

module VCAP::CloudController
  module SchemaHelper
    class << self
      def record_accessed_columns
        return unless ENV['USED_COLUMNS']

        Sequel::Model.plugin :accessed_model_columns
      end

      def dump_used_columns
        return unless ENV['USED_COLUMNS']

        data = {}
        Sequel::Model.sub_classes.reject { |c| test_model?(c) }.sort { |a, b| a.to_s <=> b.to_s }.each do |model_class|
          accessed_columns = model_class.accessed_columns
          accessed_columns = Set.new(accessed_columns).add(model_class.primary_key.to_s).to_a unless no_primary_key?(model_class)
          data[model_class.to_s] = accessed_columns.sort
        end
        used_columns_filename = File.join(Paths::ARTIFACTS, 'used_columns.json')
        File.open(used_columns_filename, 'w') do |file|
          file.write(MultiJson.dump(data, pretty: true))
        end
      end

      private

      def test_model?(model_class)
        # spec/support/bootstrap/fake_model_tables.rb
        model_class.to_s =~ /.*TestModel.*|VCAP::RestAPI::.*/
      end

      def no_primary_key?(model_class)
        # Models based on datasets don't (necessarily) have an 'id' field
        model_class.to_s =~ /.*Role|.*::View/
      end
    end
  end
end
