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

      def undef! key
        @opts.delete(key)
        self
      end

      def notext!
        @string = false
        self
      end

      def merged! with = {}, add_extra = []
        self.class.new(@string, @opts.merge(with), @extras + add_extra)
      end

      def merge_arg args, key, default = nil
        merged(key => args.empty? ? default : args.first)
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

      def join *args
        ref = self
        args.each do |arg|
          ref = ref + arg
        end
        ref
      end

      def to_plain
        "".tap do |r|
          r << @string
          @extras.each do |extra|
            r << extra.to_plain
          end
        end
      end

      def as_data
        r = []
        nopts = @opts.except(:merge_on_self)
        nopts[:text] = @string if @string
        r << nopts.compact

        @extras.each do |extra|
          r << extra.as_data
        end

        r.flatten
      end

      def to_s
        r = []
        # r << '{"text":""}' if @extras.any?
        r << '""' if @extras.any?
        if (@opts.keys - [:merge_on_self]).empty?
          r << %{"#{@string.gsub("\n", "\\n")}"}
        else
          nopts = @opts.except(:merge_on_self)
          nopts[:text] = @string if @string
          r << nopts.compact.to_json
        end

        @extras.each do |extra|
          r << extra.to_s
        end
        r.reject!.with_index{|_r, i| i != 0 && _r == '""' }
        r.join(",")
      end
      alias_method :to_str, :to_s

      def tell target = "@s"
        "tellraw #{target} [#{to_s}]"
      end

      def finalize_delayed!
        _finalize_delayed_recursive(@opts, @opts)
        @extras.each(&:finalize_delayed!)
      end

      def _finalize_delayed_recursive _data, parent, key = nil
        case _data
        when Hash
          _data.each {|k, v| _finalize_delayed_recursive(v, _data, k) }
        when Array
          _data.each {|v| _finalize_delayed_recursive(v, _data) }
        when Proc
          parent[key] = _data.call
        end
      end

      def method_missing method, *a, **kw, &b
        ::Kernel.puts "DELEGATING:#{method}:#{a}"
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
      %i[
        black dark_blue dark_green dark_aqua dark_red dark_purple gold gray
        dark_gray blue green aqua red light_purple yellow white
      ].each do |meth|
        define_method(meth) { merged(color: meth) }
      end
      define_method(:magenta) { merged(color: :light_purple) }
      define_method(:cyan) { merged(color: :aqua) }

      def color clr
        merged(color: clr)
      end

      # Events
      def click farg = nil, **kw
        kw[:run] = farg if farg

        if kw.key?(:run) || kw.key?(:suggest)
          cmd = kw[:run] || kw[:suggest]
          if cmd.start_with?("/")
            raise "cannot resolve functions without remid context" unless Thread.current[:fparse_inst]
            cmd = Thread.current[:fparse_inst].resolve_fcall(cmd.delete_prefix("/")).prepend("/")
          end
          cmd = cmd.delete_prefix("~")
          merged(clickEvent: { action: (kw.key?(:run) ? "run_command" : "suggest_command"), value: cmd })
        elsif kw.key?(:url)
          url = kw[:url]
          url = url.prepend("https://") unless url.start_with?("http")
          merged(clickEvent: { action: "open_url", value: url })
        elsif kw.key?(:copy)
          merged(clickEvent: { action: "copy_to_clipboard", value: kw[:copy] })
        elsif kw.key?(:page)
          pl = kw[:page]
          if pl.nil?
            pl = 1
          elsif !pl.is_a?(Numeric)
            pl = proc {
              book = Thread.current[:__book]
              raise "failed to lookup page number without book context" unless book
              (book.pages.index(kw[:page].to_sym) || 0) + 1
            }
          end
          pl = 0 unless pl
          merged(clickEvent: { action: "change_page", value: pl })
        else
          raise "unknown click type #{kw}"
        end
      end

      def hover farg = nil, **kw
        kw[:text] = farg if farg

        if kw.key?(:text)
          if kw[:text].is_a?(PresentedMinecraftString)
            kw[:text] = kw[:text].as_data
          end
          merged(hoverEvent: { action: "show_text", value: kw[:text] })
        else
          raise "unknown hover type #{kw}"
        end
      end

      def score objective, name = "*", resolve_objective: true
        if resolve_objective
          raise "cannot resolve functions without remid context" unless Thread.current[:fparse_inst]
          objective = Thread.current[:fparse_inst].resolve_objective(objective)
        end
        merged(score: { objective: objective, name: name }).notext!
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
