require 'mirah/jvm/source_generator/builder'

module Mirah::JavaSource
  class ClassBuilder
    def build_jsni_method(name, visibility, static, exceptions, type, *args)
      finish_declaration
      type ||= Mirah::AST.type(nil, :void)
      @methods << JsniMethodBuilder.new(self,
        :name => name,
        :visibility => visibility,
        :static => static,
        :return => type,
        :args => args,
        :exceptions => exceptions)
      @methods[-1]
    end
  end

  class JsniMethodBuilder < MethodBuilder
    include Helper

    attr_accessor :name, :type, :out

    def initialize(cls, options)
      super(cls, options)
    end

    # Based on superclass's method.
    def start
      print "public#{@static} native #{@typename} #{@name}("
      @args.each_with_index do |(type, name), i|
        print ', ' unless i == 0
        print "#{type.to_source} #{name}"
      end
      print ')'
      unless @exceptions.empty?
        print ' throws '
        @exceptions.each_with_index do |exception, i|
          print ', ' unless i == 0
          print exception.name
        end
      end
      puts ' /*-{'
    end

    # Based on superclass's method.
    def stop
      puts '}-*/;'
    end
  end
end

module Mirah::Compiler
  class JVMCompilerBase
    # arg_types must be an Array
    def create_method_builder(name, node, static, exceptions, return_type, arg_types)
      unless node.class == Mirah::AST::JsniMethodDefinition
        @class.build_method(name.to_s, node.visibility, static,
          exceptions, return_type, *arg_types)
      else
        @class.build_jsni_method(name.to_s, node.visibility, static,
          exceptions, return_type, *arg_types)
      end
    end
  end

  class JavaSource < JVMCompilerBase
    def define_jsni_method(node)
      base_define_method(node, false) do |method, arg_types|
        with :method => method do
          log "Starting new JSNI method #{node.name}"
          @method.start

          @method.puts node.body.literal.chomp

          log "JSNI method #{node.name} complete!"
          @method.stop
        end
      end
    end
  end
end

module Mirah::AST
  class JsniMethodDefinition < MethodDefinition
    def initialize(static, parent, line_number, name, annotations=[], &block)
      super(parent, line_number, name, annotations, &block)
      @static = static
    end

    def compile(compiler, expression)
      compiler.define_jsni_method(self)
    end

    def infer(typer)
      @static ||= scope.static_scope.self_type.meta? unless scope.nil?
      @defining_class ||= begin
        static_scope.self_type = if static?
          scope.static_scope.self_type.meta
        else
          scope.static_scope.self_type
        end
      end
      resolve_if(typer) do
        argument_types = typer.infer(arguments)
        if argument_types.all?
          typer.learn_method_type(defining_class, name, argument_types,
            signature[:return], signature[:throws])
        end
      end
    end

    # JSNI can't be abstract.
    def abstract?
      false
    end

    def static?
      @static
    end
  end

  defmacro 'def_jsni' do |transformer, fcall, parent|
    args = fcall.parameters

    unless args.size == 3
      raise "def_jsni must have 3 arguments."
    end

    call_node = args[1]
    if Self === call_node.target
      is_static = true
    end

    JsniMethodDefinition.new(is_static,
      parent,
      fcall.position,
      call_node.name,
      transformer.annotations) do |defn|

      signature = {:return => Mirah::AST.type(nil, args[0].name)}
      method = call_node.parameters[0]

      unless method.nil?
        hash_node = method.parameters[0]

        args = Arguments.new(defn, defn.position) do |args_new|
          arg_list = []
          hash_node.child_nodes.each_slice(2) do |name, type|
            position = name.position + type.position
            name = name.literal
            type = Mirah::AST.type(nil, type.name)
            signature[name.intern] = type
            arg_list.push(RequiredArgument.new(args_new, position, name))
          end
          [arg_list, nil, nil, nil]
        end
      else
        args = Arguments.new(defn, defn.position) do |args_new|
          [nil, nil, nil, nil]
        end
      end

      body_node = fcall.parameters[-1]

      [
        signature,
        args,
        body_node
      ]
    end
  end
end