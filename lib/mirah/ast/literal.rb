module Mirah::AST
  class Array < Node
    def initialize(parent, line_number, &block)
      super(parent, line_number, &block)
    end

    def infer(typer)
      children.each do |kid|
        kid.infer(typer)
      end
      @inferred_type = typer.array_type
    end
  end

  class Fixnum < Node
    include Literal

    def initialize(parent, line_number, literal)
      super(parent, line_number)
      @literal = literal
    end

    def infer(typer)
      resolve_if(typer) {@inferred_type = typer.fixnum_type(@literal)}
    end

    def ==(other)
      @literal == other.literal
    end

    def eql?(other)
      self.class == other.class && @literal.eql?(other.literal)
    end
  end

  class Float < Node
    include Literal

    def initialize(parent, line_number, literal)
      super(parent, line_number)
      @literal = literal
    end

    def infer(typer)
      resolve_if(typer) {@inferred_type = typer.float_type(@literal)}
    end
  end

  class Hash < Node; end

  class Regexp < Node
    include Literal

    def initialize(parent, line_number, literal)
      super(parent, line_number)
      @literal = literal
    end

    def infer(typer)
      return @inferred_type if resolved?
      resolved!
      @inferred_type ||= typer.regexp_type
    end
  end

  class String < Node
    include Literal
    include Scoped
    include Java::DubyLangCompiler.StringNode

    def initialize(parent, line_number, literal)
      super(parent, line_number)
      @literal = literal
    end

    def infer(typer)
      return @inferred_type if resolved?
      resolved!
      @inferred_type ||= typer.string_type
    end

    def type_reference(typer)
      typer.type_reference(scope, @literal)
    end

    def toString
      @literal
    end
  end

  class StringConcat < Node
    def initialize(parent, position, &block)
      super(parent, position, &block)
    end

    def infer(typer)
      unless resolved?
        resolved = true
        children.each {|node| node.infer(typer); resolved &&= node.resolved?}
        resolved! if resolved
        @inferred_type ||= typer.string_type
      end
      @inferred_type
    end
  end

  class ToString < Node
    child :body

    def initialize(parent, position)
      super(parent, position)
    end

    def infer(typer)
      unless resolved?
        body.infer(typer)
        resolved! if body.resolved?
        @inferred_type ||= typer.string_type
      end
      @inferred_type
    end
  end

  class Symbol < Node; end

  class Boolean < Node
    include Literal

    def initialize(parent, line_number, literal)
      super(parent, line_number)
      @literal = literal
    end

    def infer(typer)
      return @inferred_type if resolved?
      resolved!
      @inferred_type ||= typer.boolean_type
    end
  end

  class Null < Node
    include Literal

    def initialize(parent, line_number)
      super(parent, line_number)
    end

    def infer(typer)
      return @inferred_type if resolved?
      resolved!
      @inferred_type ||= typer.null_type
    end
  end
end