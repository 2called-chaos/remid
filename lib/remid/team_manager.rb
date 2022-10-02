module Remid
  class TeamManager < Hash
    attr_accessor :namespace

    def initialize parent
      @parent = parent
    end

    def add key, **kw
      rkey = key.is_a?(Symbol) ? "#{@parent.function_namespace}_#{key}" : key
      raise "duplicate team error #{rkey} already taken" if self[rkey]
      self[rkey] = Team.new(self, rkey, **kw)
    end

    def create_all cbuf: nil
      cbuf = $remid.buf(cbuf)
      ref1 = self
      cbuf << proc {|cbuf|
        ref1.each do |key, obj|
          obj.create(cbuf: cbuf)
        end
      }
    end

    def destroy_all cbuf: nil
      cbuf = $remid.buf(cbuf)
      ref1 = self
      cbuf << proc {|cbuf|
        ref1.each do |key, obj|
          obj.destroy(cbuf: cbuf)
        end
      }
    end

    def method_missing meth, *args, **kwargs, &block
      if args.empty? && kwargs.empty?
        self[meth.to_s] || self["#{@parent.function_namespace}_#{meth}"] || super
      else
        super
      end
    end
  end
end
