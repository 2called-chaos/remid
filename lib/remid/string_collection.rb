module Remid
  class StringCollection
    attr_reader :context, :scope

    def initialize context = nil, scope = []
      @scope = scope
      @context = context
      @store = {}
    end

    def store storage, *args, **kw, &block
      JsonStorageContext.new(storage, self, *args, **kw, &block)
    end

    def build key, &block
      if block.arity == 0
        @store[key] = JsonHelper::PresentedMinecraftStringBase.wrap(block.call(*args, **kw))
      else
        out = JsonHelper::PresentedMinecraftStringBase.wrap("")
        block.call(out, *args, **kw)
        @store[key] = out
      end
    end

    def inspect
      "<#{self.class}::#{scope.join(":")}>"
    end

    def method_missing key, *args, **kw, &block
      if key.to_s.end_with?("=")
        @store[key.to_s[0..-2].to_sym] = proc{ args.first }
      elsif block
        @store[key] = block
      else
        case v = @store[key]
        when Proc
          v.call(*args)
        when StringCollection, String
          v
        else
          super
        end
      end
    end

    def group key
      @store[key] = StringCollection.new(@context, scope + [key])
      yield(@store[key]) if block_given?
      @store[key]
    end
  end
end
