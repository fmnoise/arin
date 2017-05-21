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
        queries.join <<-SQL
          UNION ALL
        SQL
      end

      def queries
        [].tap do |qs|
          classes.each do |klass|
            klass.reflect_on_all_associations(:belongs_to).each do |relation|
              begin
                if is_polymorphic?(relation)
                  polymorphics(klass, relation).each do |poly|
                    poly_class = poly.safe_constantize
                    if poly_class
                      qs << polymorphic_relation_query(klass, relation, poly_class)
                    else
                      qs << broken_polymorchic_class_query(klass, relation, poly)
                    end
                  end
                else
                  qs << relation_query(klass, relation) if processable?(klass, relation)
                end
              rescue StandardError => e
                handle_query_failure(klass, relation, e)
              end
            end
          end
        end
      end

      def processable?(klass, relation)
        klass.table_exists? &&
        klass.primary_key &&
        klass.column_names.include?(relation.foreign_key) &&
        relation.klass
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

      def polymorphic_relation_query(klass, relation, relation_class)
        <<-SQL
          SELECT "#{klass.name}" AS class_name,
            t.#{klass.primary_key} AS id,
            "#{relation_class}" AS relation_class,
            t.#{relation.foreign_key} AS relation_id
          FROM #{klass.table_name} AS t
          LEFT JOIN #{relation_class.table_name} AS r
            ON t.#{relation.foreign_key} = r.#{relation_class.primary_key}
            AND t.#{relation.foreign_type} = "#{relation_class}"
          WHERE r.#{relation_class.primary_key} IS NULL
            AND t.#{relation.foreign_key} IS NOT NULL
        SQL
      end

      def broken_polymorphic_class_query(klass, relation, relation_class)
        <<-SQL
          SELECT "#{klass.name}" AS class_name,
            t.#{klass.primary_key} AS id,
            "#{relation_class}" AS relation_class,
            t.#{relation.foreign_key} AS relation_id
          FROM #{klass.table_name} AS t
          WHERE t.#{relation.foreign_type} = "#{relation_class}"
        SQL
      end

      def polymorphics(klass, relation)
        klass.pluck(relation.foreign_type).uniq
      end

      def is_polymorphic?(relation)
        relation.options[:polymorphic]
      end

      def handle_query_failure(klass, relation, e)
        warn("Cannot process #{relation.name} relation for #{klass}: #{e.message}")
      end
  end
end
