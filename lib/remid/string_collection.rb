module Remid
  class StringCollection
    def initialize
      @store = {}
    end

    def method_missing key, *args, **kw, &block
      if key.to_s.end_with?("=")
        @store[key.to_s[1..-2].to_sym] = proc{ args.first }
      elsif block
        @store[key] = block
      else
        case v = @store[key]
        when Proc
          if v.arity == 0
            JsonHelper::PresentedMinecraftStringBase.wrap(@store[key].call(*args, **kw))
          else
            out = JsonHelper::PresentedMinecraftStringBase.wrap("")
            if kw.empty?
              @store[key].call(out, *args)
            else
              @store[key].call(out, *args, **kw)
            end
            out
          end
        when StringCollection, String
          v
        else
          super
        end
      end
    end

    def group key
      @store[key] = StringCollection.new
    end
  end
end
