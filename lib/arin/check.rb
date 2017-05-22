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
        queries.compact.join <<-SQL
          UNION ALL
        SQL
      end

      def queries
        classes.reduce([]) do |qs, klass|
          qs.push(*class_queries(klass))
        end
      end

      def class_queries klass
        associations_for(klass).reduce([]) do |qs, assoc|
          qs.push(*association_queries(assoc, klass))
        end
      end

      def association_queries assoc, klass
        if is_polymorphic?(assoc)
          polymorphic_association_queries(assoc, klass)
        else
          association_query(assoc, klass) if processable?(assoc, klass)
        end
      rescue StandardError => e
        handle_query_failure(assoc, klass, e)
      end

      def polymorphic_association_queries assoc, klass
        polymorphics(assoc, klass).map do |poly_class_name|
          poly_class = poly_class_name.safe_constantize
          if poly_class
            polymorphic_association_query(assoc, klass, poly_class)
          else
            broken_polymorchic_class_query(assoc, klass, poly_class_name)
          end
        end
      end

      def associations_for klass
        klass.reflect_on_all_associations(:belongs_to)
      end

      def processable?(assoc, klass)
        klass.table_exists? &&
        klass.primary_key &&
        klass.column_names.include?(assoc.foreign_key)
      end

      def association_query(assoc, klass)
        <<-SQL
          SELECT "#{klass.name}" AS class_name,
            t.#{klass.primary_key} AS id,
            "#{assoc.class_name}" AS relation_class,
            t.#{assoc.foreign_key} AS relation_id
          FROM #{klass.table_name} AS t
          LEFT JOIN #{assoc.table_name} AS r
            ON t.#{assoc.foreign_key} = r.#{assoc.association_primary_key}
          WHERE r.#{assoc.association_primary_key} IS NULL
            AND t.#{assoc.foreign_key} IS NOT NULL
        SQL
      end

      def polymorphic_association_query(assoc, klass, assoc_class)
        <<-SQL
          SELECT "#{klass.name}" AS class_name,
            t.#{klass.primary_key} AS id,
            "#{assoc_class}" AS relation_class,
            t.#{assoc.foreign_key} AS relation_id
          FROM #{klass.table_name} AS t
          LEFT JOIN #{assoc_class.table_name} AS r
            ON t.#{assoc.foreign_key} = r.#{assoc_class.primary_key}
          WHERE r.#{assoc_class.primary_key} IS NULL
            AND t.#{assoc.foreign_key} IS NOT NULL
            AND t.#{assoc.foreign_type} = "#{assoc_class}"
        SQL
      end

      def broken_polymorphic_class_query(assoc, klass, assoc_class_name)
        <<-SQL
          SELECT "#{klass.name}" AS class_name,
            t.#{klass.primary_key} AS id,
            "#{assoc_class}" AS relation_class,
            t.#{assoc.foreign_key} AS relation_id
          FROM #{klass.table_name} AS t
          WHERE t.#{assoc.foreign_type} = "#{assoc_class_name}"
        SQL
      end

      def polymorphics(assoc, klass)
        klass.pluck(assoc.foreign_type).uniq.compact
      end

      def is_polymorphic?(assoc)
        assoc.options[:polymorphic]
      end

      def handle_query_failure(assoc, klass, e)
        warn("Cannot process #{assoc.name} relation for #{klass}: #{e.message}")
      end
  end
end
