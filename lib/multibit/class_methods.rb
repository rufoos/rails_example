module Multibit
  module ClassMethods
    def inherited(subclass) # :nodoc:
      ::States::INHERITABLE_CLASS_ATTRIBUTES.each do |attribute|
        instance_var = "@#{attribute}"
        subclass.instance_variable_set(instance_var, instance_variable_get(instance_var))
      end
      super
    end

    def mask_for(state_attribute_name, *states)
      sanitized_states = states.map { |state| Array(state) }.flatten.map(&:to_sym)
      (valid_states[state_attribute_name] & sanitized_states).inject(0) { |sum, state| sum + 2**valid_states[state_attribute_name].index(state) }
    end

    def multibit(params)
      params.each do |field, states|
        self.valid_states.merge!({field => states.flatten.map(&:to_sym)})
        self.define_dynamic_queries_for_field(field, self.valid_states[field])
      end

      # opts = states.last.is_a?(Hash) ? states.pop : {}
      # unless (opts[:dynamic] == false)
      # end
    end
    
    protected

    # Define methods by field name.
    # Example:
    # mutlibit settings: :
    def define_dynamic_queries_for_field(field, states)
      dynamic_module = Module.new do
        define_method("has_#{field.to_s.singularize}?".to_sym){ |*states| has_any? field, states }
        define_method("has_#{field.to_s.pluralize}?".to_sym){ |*states| has_all? field, states }
        states.each do |state|
          define_method("has_#{field.to_s.singularize}_#{state}?".to_sym){ has_only? field, state }
        end
        define_method(field){ bitmask(field) }
        define_method("#{field}=".to_sym){ |values| bitmask_add(field, values) }
      end
      include dynamic_module
    end

  end
end
