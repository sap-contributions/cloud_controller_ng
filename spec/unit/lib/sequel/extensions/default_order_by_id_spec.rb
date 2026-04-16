# frozen_string_literal: true

require 'spec_helper'
require 'sequel/extensions/default_order_by_id'

RSpec.describe 'Sequel::DefaultOrderById' do
  let(:model_class) { VCAP::CloudController::Organization }
  let(:db) { model_class.db }

  def capture_sql(&)
    sqls = []
    db.loggers << (logger = Class.new do
      define_method(:info) { |msg| sqls << msg if msg.include?('SELECT') }
      define_method(:debug) { |_| }
      define_method(:error) { |_| }
    end.new)
    yield
    db.loggers.delete(logger)
    sqls.last
  end

  describe 'default ordering' do
    it 'adds ORDER BY id to model queries' do
      sql = capture_sql { model_class.dataset.first }
      expect(sql).to match(/ORDER BY .id./)
    end
  end

  describe 'already_ordered?' do
    it 'preserves explicit ORDER BY' do
      sql = capture_sql { model_class.dataset.order(:name).first }
      expect(sql).to match(/ORDER BY .name./)
      expect(sql).not_to match(/ORDER BY .id./)
    end
  end

  describe 'incompatible_with_order?' do
    it 'skips for GROUP BY' do
      ds = model_class.dataset.group(:status)
      expect(ds.sql).not_to match(/ORDER BY/)
    end

    it 'skips for compound queries (UNION)' do
      ds1 = model_class.dataset.where(name: 'a')
      ds2 = model_class.dataset.where(name: 'b')
      sql = capture_sql { ds1.union(ds2, all: true, from_self: false).all }
      expect(sql).not_to match(/\) ORDER BY/)
    end

    it 'skips for DISTINCT ON' do
      sql = capture_sql { model_class.dataset.distinct(:guid).all }
      expect(sql).not_to match(/ORDER BY/)
    end

    it 'skips for from_self (subquery)' do
      sql = capture_sql { model_class.dataset.where(name: 'a').from_self.all }
      expect(sql).to match(/AS .t1.$/)
    end
  end

  describe 'not_a_data_query?' do
    it 'skips for schema introspection (columns!)' do
      sql = capture_sql { model_class.dataset.columns! }
      expect(sql).not_to match(/ORDER BY/)
    end
  end

  describe 'model_has_id_primary_key?' do
    it 'skips for models with non-id primary key' do
      guid_pk_model = Class.new(Sequel::Model(db[:organizations])) do
        set_primary_key :guid
      end
      sql = capture_sql { guid_pk_model.dataset.first }
      expect(sql).not_to match(/ORDER BY/)
    end
  end

  describe 'find_id_column' do
    context 'with SELECT *' do
      it 'uses unqualified :id' do
        sql = capture_sql { model_class.dataset.first }
        expect(sql).to match(/ORDER BY .id./)
        expect(sql).not_to match(/ORDER BY .organizations.\..id./)
      end

      it 'uses qualified column for JOIN to avoid ambiguity' do
        sql = capture_sql { model_class.dataset.join(:spaces, organization_id: :id).first }
        expect(sql).to match(/ORDER BY .organizations.\..id./)
      end
    end

    context 'with SELECT table.*' do
      it 'uses unqualified :id' do
        sql = capture_sql { model_class.dataset.select(Sequel::SQL::ColumnAll.new(:organizations)).join(:spaces, organization_id: :id).first }
        expect(sql).to match(/ORDER BY .id./)
        expect(sql).not_to match(/ORDER BY .organizations.\..id./)
      end
    end

    context 'with qualified id in select list' do
      it 'uses the qualified column' do
        sql = capture_sql { model_class.dataset.select(:organizations__id, :organizations__name).first }
        expect(sql).to match(/ORDER BY .organizations.\..id./)
      end
    end

    context 'with aliased id in select list' do
      it 'uses the alias' do
        sql = capture_sql { model_class.dataset.select(Sequel.as(:organizations__id, :id), :name).first }
        expect(sql).to match(/ORDER BY .id./)
      end
    end

    context 'without id in select list' do
      it 'skips ordering' do
        sql = capture_sql { model_class.dataset.select(:guid, :name).all }
        expect(sql).not_to match(/ORDER BY/)
      end
    end
  end
end
