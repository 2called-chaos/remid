module Remid
  class FunctionScheduler
    attr_accessor :namespace

    def initialize parent
      @parent = parent
    end

    def cancel_all
      raise "no context" unless cbuf = Thread.current[:fparse_cbuf]
      @parent.functions.each do |name, _|
        cbuf << "schedule clear #{@namespace}:#{name}"
      end
    end
  end
end
