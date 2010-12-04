require 'delegate'

module Mirah::JVM::Types

  # Represents a literal number that can be represented
  # in multiple types
  class NarrowingType < DelegateClass(PrimitiveType)
    def initialize(default_type, narrowed_type)
      super(default_type)
      @narrowed = default_type != narrowed_type && narrowed_type
    end
    
    def hash
      __getobj__.hash
    end

    # Changes this type to the smallest type that will hold
    # its literal value.
    def narrow!
      if @narrowed
        __setobj__(@narrowed)
        true
      end
    end
  end
  
  class FixnumLiteral < NarrowingType
    def self.range(type)
      type::MIN_VALUE .. type::MAX_VALUE
    end
    
    BYTE_RANGE = range(java.lang.Byte)
    SHORT_RANGE = range(java.lang.Short)
    INT_RANGE = range(java.lang.Integer)
    LONG_RANGE = range(java.lang.Long)

    def initialize(literal)
      default_type = case literal
      when INT_RANGE
        Int
      else
        Long
      end
      
      # TODO chars?
      # There's not really any way to tell if we should narrow to a char
      # or a byte/short.  I suppose we could try both, but that seems ugly.
      # Maybe it's the right thing to do though?
      narrowed_type = case literal
      when BYTE_RANGE
        Byte
      when SHORT_RANGE
        Short
      when INT_RANGE
        Int
      else
        Long
      end
      
      super(default_type, narrowed_type)
    end
  end

  class FloatLiteral < NarrowingType
    FLOAT_RANGE = java.lang.Float::MIN_VALUE .. java.lang.Float::MAX_VALUE
    NaN = java.lang.Float::NaN
    POSITIVE_INFINITY = java.lang.Float::POSITIVE_INFINITY
    NEGATIVE_INFINITY = java.lang.Float::NEGATIVE_INFINITY

    def initialize(literal)
      super(Double, Double)
    end
  end
end