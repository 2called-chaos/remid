module Remid
  class ObjectiveManager < Hash
    attr_accessor :namespace

    def initialize parent
      @parent = parent
    end

    def add key, type = "dummy", **kw
      rkey = key.is_a?(Symbol) ? "#{@namespace}_#{key}" : key
      raise "duplicate objective error #{rkey} already taken" if self[rkey]
      self[rkey] = Objective.new(self, rkey, type, **kw)
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
        if meth.to_s.end_with?("?")
          !!(self[meth.to_s[0..-2]] || self["#{@namespace}_#{meth.to_s[0..-2]}"])
        else
          self[meth.to_s] || self["#{@namespace}_#{meth}"] || super
        end
      else
        super
      end
    end
  end
end
