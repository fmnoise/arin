module Arin
  class Issue
    attr_reader :class_name, :id, :relation_class, :relation_id

    def initialize(class_name:, id:, relation_class:, relation_id:)
      @class_name = class_name
      @id = id
      @relation_class = relation_class
      @relation_id = relation_id
    end

    def object
      @object ||= class_name.constantize.find(id)
    end
  end
end
