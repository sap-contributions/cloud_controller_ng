module Sequel::Plugins
  module AccessedModelColumns
    module ClassMethods
      def add_accessed_column(column)
        Sequel.synchronize do
          (@accessed_columns ||= Set[]).add(column.to_s) if self.db_schema.include?(column)
        end
      end

      def accessed_columns
        Sequel.synchronize do
          @accessed_columns ? @accessed_columns.to_a : []
        end
      end
    end

    module InstanceMethods
      def [](column)
        self.class.add_accessed_column(column)
        super
      end
    end
  end
end
