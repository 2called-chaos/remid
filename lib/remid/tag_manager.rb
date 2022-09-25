module Remid
  class TagManager
    TYPES = %i[blocks entities functions]
    attr_reader :context, :tags

    def initialize context
      @context = context
      @tags = TYPES.each_with_object({}) do |type, h|
        h[type] = TagType.new(self, type)
      end
    end

    TYPES.each do |meth|
      define_method(meth) do |*args, **kwargs|
        if args.empty?
          @tags[meth]
        else
          @tags[meth].add(*args, **kwargs)
        end
      end
    end

    class TagType
      attr_reader :type, :tags

      def initialize(manager, type)
        @manager = manager
        @type = type
        @tags = {}
        @replace = false
      end

      def [] key
        @tags[key]
      end

      def default_prefix
        @type == :functions ? :_ : :minecraft
      end

      def function_namespace
        @manager.context.function_namespace
      end

      def add key, values = [], **kw
        if @tags[key]
          raise "#{@type} tag `#{key}' already defined, add to list instead"
        end

        @tags[key] = Tag.new(self, key, values, **kw)
      end
    end

    class Tag
      attr_accessor :replace
      attr_reader :key, :values

      def initialize(tag_type, key, values = [], **kw)
        @tag_type = tag_type
        @key = key
        @values = Set.new
        @replace = kw.key?(:replace) ? kw[:replace] : false
        if values.any?
          add(values, **kw.slice(:prefix))
        end
      end

      def add values, **kw
        defprefix = kw.key?(:prefix) ? kw[:prefix] : @tag_type.default_prefix
        defprefix = @tag_type.function_namespace if defprefix == :_
        values.each do |_v|
          v = _v.to_s
          if v.start_with?(":")
            @values << "#{@tag_type.function_namespace}#{v}"
          elsif v[":"] || !defprefix
            @values << v
          else
            @values << "#{defprefix}:#{v}"
          end
        end
      end

      def << *values
        add(values.flatten)
      end

      def as_data
        {
          replace: @replace,
          values: @values.to_a,
        }
      end

      def as_json
        as_data.to_json
      end
    end
  end
end
