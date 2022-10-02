module Remid
  module JsonHelper
    class PresentedMinecraftStringBase
      attr_reader :opts

      def self.wrap me
        return me if me.is_a?(PresentedMinecraftStringBase)
        PresentedMinecraftString.new(me)
      end

      def initialize(string, opts = {}, extras = [])
        @string = string
        @opts = opts
        @extras = extras
      end

      def merged with = {}
        if @opts[:merge_on_self]
          @opts.merge!(with)
          self
        else
          merged!(with)
        end
      end

      def merged! with = {}, add_extra = []
        self.class.new(@string, @opts.merge(with), @extras + add_extra)
      end

      def merge_arg args, key, default = nil
        merged(key => args.any? ? args.first : default)
      end

      def wrap *whats
        return self if whats.empty?
        self.class.wrap(whats.first)
      end

      def + val
        merged!({}, [wrap(val)])
      end

      def << val
        @extras << wrap(val)
        self
      end

      def to_s
        r = []
        if (@opts.keys - [:merge_on_self]).empty?
          r << %{"#{@string}"}
        else
          r << @opts.merge(text: @string).except(:merge_on_self).compact.to_json
        end

        @extras.each do |extra|
          r << extra.to_s
        end
        r.join(",")
      end
      alias_method :to_str, :to_s

      def method_missing method, *a, **kw, &b
        puts "DELEGATING:#{method}:#{a}"
        @string.send(method, *a, **kw, &b)
      end

      def respond_to_missing?(method_name, include_private = false)
        @string.respond_to?(method_name, include_private) || super
      end
    end

    class PresentedMinecraftString < PresentedMinecraftStringBase
      def reset *args
        args << :underlined if args.delete(:underline)
        if @opts[:merge_on_self]
          args = @opts.keys - [:merge_on_self] if args.empty?
          args.each {|key| @opts.delete(key) }
        else
          if args.any?
            self.class.new(@string, @opts.except(*args))
          else
            self.class.new(@string, @opts.slice(:merge_on_self))
          end
        end
      end

      # General formatting
      [:bold, :italic, :underlined, :strikethrough, :obfuscated].each do |meth|
        define_method(meth) do |*args|
          merge_arg(args, meth, true)
        end
      end
      alias_method :underline, :underlined

      # Fonts
      def font name
        merged(font: name)
      end

      # Colors
      %i[black dark_blue dark_green dark_aqua dark_red dark_purple gold gray dark_gray blue green aqua red light_purple yellow white].each do |meth|
        define_method(meth) { merged(color: meth) }
      end

      def color clr
        merged(color: clr)
      end

      # Events
      def click farg = nil, **kw
        kw[:run] = farg if farg
        merged(click: kw)
      end

      def hover farg = nil, **kw
        kw[:text] = farg if farg
        merged(hover: kw)
      end
    end

    refine String do
      PresentedMinecraftString.instance_methods(false).each do |meth|
        define_method(meth) do |*args, **kw, &block|
          PresentedMinecraftString.new(self).send(meth, *args, **kw, &block)
        end
      end

      def wrap
        PresentedMinecraftStringBase.wrap(self)
      end
    end
  end
end
