require 'set'

module Multibit
  class Bitmask < ::Set # :nodoc:
    attr_reader :model_instance, :state_attribute_name

    def initialize(sender, state_attribute_name, states)
      super(states)
      @state_attribute_name = state_attribute_name
      @model_instance = sender
    end

    def add(state)
      states = super
      model_instance.bitmask_add(state_attribute_name, states) if model_instance
      self
    end

    alias_method :<<, :add

    def delete(state)
      if state.is_a? Array
        model_instance.bitmask_add(state_attribute_name, subtract(state))
      else
        model_instance.bitmask_add(state_attribute_name, super(state.to_sym))
      end
      self
    end

  end
end
