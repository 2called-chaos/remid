module Remid
  class FunctionScheduler
    attr_accessor :namespace

    def initialize parent
      @parent = parent
      @scheduled = Set.new
    end

    def schedule function, schedule_when = nil, append: false
      if schedule_when && schedule_when != "clear"
        @scheduled << function
        "schedule function #{function} #{schedule_when}".tap{|s| s << " append" if append }
      else
        "schedule clear #{function}"
      end
    end

    def cancel_all which = :scheduled
      raise "no context" unless cbuf = Thread.current[:fparse_cbuf]

      if which == :scheduled
        cbuf << proc {|cbuf|
          @scheduled.each do |name|
            cbuf << "actually schedule clear #{name}"
          end
        }
      elsif which == :functions
        @parent.functions.each do |name, _|
          cbuf << "schedule clear #{@namespace}:#{name}"
        end
      else
        raise "don't know how to cancel `#{which}'"
      end
    end
  end
end
