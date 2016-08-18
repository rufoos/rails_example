module Multibit
  module Implementation

    def has_all?(state_attribute_name, *states)
      states.flatten.map(&:to_sym).all? { |r| self.bitmask(state_attribute_name).include?(r) }
    end

    def has_any?(state_attribute_name, *states)
      states.flatten.map(&:to_sym).any? { |r| self.bitmask(state_attribute_name).include?(r) }
    end

    def has_only?(state_attribute_name, *states)
      self.read_attribute(state_attribute_name) == self.class.mask_for(state_attribute_name, *states)
    end

    def bitmask_add(state_attribute_name, *states)
      self.write_attribute(state_attribute_name, self.class.mask_for(state_attribute_name, *states))
    end

    def bitmask(state_attribute_name)
      Bitmask.new(self, state_attribute_name, self.class.valid_states[state_attribute_name].reject { |r| ((self.read_attribute(state_attribute_name) || 0) & 2**self.class.valid_states[state_attribute_name].index(r)).zero? })
    end

  end
end
