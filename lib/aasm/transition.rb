module AASM
  class Transition
    include DslHelper

    attr_reader :from, :to, :opts
    alias_method :options, :opts

    def initialize(opts, &block)
      add_options_from_dsl(opts, [:on_transition, :guard, :after], &block) if block

      @from = opts[:from]
      @to = opts[:to]
      @guards = Array(opts[:guards]) + Array(opts[:guard]) + Array(opts[:if])
      @unless = Array(opts[:unless]) #TODO: This could use a better name

      if opts[:on_transition]
        warn '[DEPRECATION] :on_transition is deprecated, use :after instead'
        opts[:after] = Array(opts[:after]) + Array(opts[:on_transition])
      end
      @after = Array(opts[:after])
      @after = @after[0] if @after.size == 1

      @opts = opts
    end

    def allowed?(obj, *args)
      invoke_callbacks_compatible_with_guard(@guards, obj, args, :guard => true) &&
      invoke_callbacks_compatible_with_guard(@unless, obj, args, :unless => true)
    end

    def execute(obj, *args)
      invoke_callbacks_compatible_with_guard(@after, obj, args)
    end

    def ==(obj)
      @from == obj.from && @to == obj.to
    end

    def from?(value)
      @from == value
    end

    private

    def invoke_callbacks_compatible_with_guard(code, record, args, options={})
      if record.respond_to?(:aasm)
        record.aasm.from_state = @from if record.aasm.respond_to?(:from_state=)
        record.aasm.to_state = @to if record.aasm.respond_to?(:to_state=)
      end

      case code
      when Symbol, String
        # QUESTION : record.send(code, *args) ?
        arity = record.send(:method, code.to_sym).arity
        arity == 0 ? record.send(code) : record.send(code, *args)
      when Proc
        # QUESTION : record.instance_exec(*args, &code) ?
        code.arity == 0 ? record.instance_exec(&code) : record.instance_exec(*args, &code)
      when Array
        if options[:guard]
          # invoke guard callbacks
          code.all? {|a| invoke_callbacks_compatible_with_guard(a, record, args)}
        elsif options[:unless]
          # invoke unless callbacks
          code.all? {|a| !invoke_callbacks_compatible_with_guard(a, record, args)}
        else
          # invoke after callbacks
          code.map {|a| invoke_callbacks_compatible_with_guard(a, record, args)}
        end
      else
        true
      end
    end

  end
end # AASM
