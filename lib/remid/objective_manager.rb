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

    def create_all
      each do |key, obj|
        obj.create
      end
    end

    def destroy_all
      each do |key, obj|
        obj.destroy
      end
    end

    def method_missing meth, *args, **kwargs, &block
      if args.empty? && kwargs.empty?
        self[meth.to_s] || self["#{@namespace}_#{meth}"] || super
      else
        super
      end
    end
  end
end
