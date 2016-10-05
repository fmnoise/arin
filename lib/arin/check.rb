require_relative './issue'

module Arin
  class Check
    attr_reader :classes

    def self.call(classes = [])
      self.new(classes).issues
    end

    def initialize(classes = [])
      @classes = Array(classes).presence || all_classes
    end

    def issues
      @issues ||= raw_results.map do |entry|
        Arin::Issue.new \
          class_name: entry['class_name'],
          id: entry['id'],
          relation_class: entry['relation_class'],
          relation_id: entry['relation_id']
      end
    end

    private

      def raw_results
        query.present? ? ActiveRecord::Base.connection.select_all(query) : []
      end

      def all_classes
        ActiveRecord::Base.descendants
      end

      def query
        subqueries = []
        classes.each do |klass|
          klass.reflect_on_all_associations(:belongs_to).each do |relation|
            q = relation_query(klass, relation) rescue nil
            subqueries << q if q && processable?(klass, relation)
          end
        end
        subqueries.join <<-SQL
          UNION ALL
        SQL
      end

      def processable?(klass, relation)
        klass.table_exists? &&
        klass.primary_key &&
        klass.column_names.include?(relation.foreign_key)
      end

      def relation_query(klass, relation)
        <<-SQL
          SELECT "#{klass.name}" AS class_name,
            t.#{klass.primary_key} AS id,
            "#{relation.class_name}" AS relation_class,
            t.#{relation.foreign_key} AS relation_id
          FROM #{klass.table_name} AS t
          LEFT JOIN #{relation.table_name} AS r
            ON t.#{relation.foreign_key} = r.#{relation.association_primary_key}
          WHERE r.#{relation.association_primary_key} IS NULL
            AND t.#{relation.foreign_key} IS NOT NULL
        SQL
      end
  end
end
