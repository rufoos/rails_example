require 'multibit/implementation'
require 'multibit/class_methods'
require 'multibit/bitmask'

module Multibit

  INHERITABLE_CLASS_ATTRIBUTES = [:valid_states]

  include Implementation

  def self.included(base)
    base.extend ClassMethods
    base.class_eval do
      class << self
        attr_accessor(*::Multibit::INHERITABLE_CLASS_ATTRIBUTES)
      end
      self.valid_states = {}
    end
  end

end