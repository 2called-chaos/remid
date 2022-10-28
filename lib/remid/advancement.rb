module Remid
  class Advancement
    attr_reader :key, :scoped_key
    attr_accessor :raw
    include FunctionParser::Resolvers

    def initialize collection, key, type = :task, **data, &block
      @collection = collection
      @context = @collection.context
      @key = key
      @type = type
      @definer = block
      @raw = {}
      @scoped_key = (@collection.scopes + [@key.gsub(":", "/")]).join("/")
      @data = {
        criteria: [],
        reward: {},
      }.deep_merge(data)
      # @opts.assert_valid_keys(:name, :display, :render, :defaults, :lazy)
    end

    def _resolve
      @defined ||= begin
        @rsrc, @li_no = @definer.source_location
        @rsrc = @rsrc.gsub("\\", "/")
        rt = @context.relative_target&.to_s.gsub("\\", "/")
        if rt && @rsrc.start_with?(rt)
          @rsrc = Pathname.new("." << @rsrc[rt.length..-1])
        end

        instance_eval(&@definer)
        true
      end
    end

    def _capture_conditions conditions, target
      cap = BlockCaptureDsl.new(target)
      cap.instance_eval(&conditions)
      cap.__data
    end

    def to_data
      to_result[:data]
    end

    def to_json pretty: false
      to_data.to_json
    end

    def to_result
      { warnings: [] }.tap do |result|
        @warnings = result[:warnings]
        _resolve
        result[:data] = jdat = JSON.parse(@raw.to_json)
        jdat.symbolize_keys!

        # clean up data
        @data[:hidden] = @data.delete(:hide) if @data.key?(:hide)
        @data[:hidden] = !@data.delete(:show) if @data.key?(:show)
        @data[:hidden] = !@data.delete(:visible) if @data.key?(:visible)
        keys = @data.keys
        keys.delete(:reward) if @data[:reward].empty?
        keys.delete(:criteria) if @data[:criteria].empty?

        serialize_parent(jdat) if keys.delete(:parent)
        jdat[:display] ||= {}
        serialize_title(jdat) if keys.delete(:title)
        serialize_description(jdat) if keys.delete(:description)
        serialize_icon(jdat) if keys.delete(:icon)
        serialize_frame(jdat)
        serialize_toast(jdat) if keys.delete(:toast)
        serialize_chat(jdat) if keys.delete(:chat)
        serialize_hidden(jdat) if keys.delete(:hidden)
        serialize_background(jdat) if keys.delete(:background)
        serialize_criteria(jdat) if keys.delete(:criteria)
        serialize_reward(jdat) if keys.delete(:reward)

        unless keys.empty?
          result[:warnings] << "#{keys.length} keys remained unprocessed: #{keys.join(", ")}"
        end
      end
    end

    class BlockCaptureDsl < BasicObject
      attr_reader :__data

      def initialize data = {}
        @__data = data
      end

      def method_missing meth, *args, **kw, &block
        if block
          @__data[meth] ||= {}
          BlockCaptureDsl.new(@__data[meth]).instance_eval(&block)
        else
          @__data[meth] = args[0]
        end
      end
    end

    module Serializers
      def serialize_parent jdat
        par = @data[:parent]
        par = @data[:parent].key if par.is_a?(Advancement)
        par = par.to_s
        par = par.prepend("#{@context.function_namespace}:") unless par[":"]
        jdat[:parent] = par
      end

      def serialize_title jdat
        jdat[:display][:title] = JSON.parse("[#{JsonHelper::PresentedMinecraftString.wrap(@data[:title])}]")
      end

      def serialize_description jdat
        jdat[:display][:description] = JSON.parse("[#{JsonHelper::PresentedMinecraftString.wrap(@data[:description])}]")
      end

      def serialize_icon jdat
        item = @data[:icon][0].to_s
        nbt = @data[:icon][1]
        item = "#{@context.function_namespace}#{item}" if item.start_with?(":")
        item = "minecraft:#{item}" unless item[":"]
        jdat[:display][:icon] = { item: item }
        jdat[:display][:icon][:nbt] = nbt if nbt
      end

      def serialize_frame jdat
        jdat[:display][:frame] = @type
      end

      def serialize_toast jdat
        jdat[:display][:show_toast] = @data[:toast]
      end

      def serialize_chat jdat
        jdat[:display][:announce_to_chat] = @data[:chat]
      end

      def serialize_hidden jdat
        jdat[:display][:hidden] = @data[:hidden]
      end

      def serialize_background jdat
        value = @data[:background]
        if value.is_a?(Symbol)
          value = "minecraft:textures/gui/advancements/backgrounds/#{value}.png"
        else
          value = value.prepend(@context.function_namespace) if value.start_with?(":")
          value = value.prepend("minecraft:") unless value[":"]
        end
        jdat[:display][:background] = value
      end

      def serialize_criteria jdat
        jdat[:criteria] ||= {}
        @data[:criteria].each_with_index do |(key, trigger, conditions), i|
          key = "cond_#{i}" if key == :index
          trigger = "minecraft:#{trigger}" if trigger.is_a?(Symbol)
          jdat[:criteria][key] = { trigger: trigger }
          if conditions
            jdat[:criteria][key][:conditions] = {}
            _capture_conditions(conditions, jdat[:criteria][key][:conditions])
          end
        end
      end

      def serialize_reward jdat
        jdat[:rewards] ||= {}
        @data[:reward].each do |k, v|
          case k
          when :function
            jdat[:rewards][:function] = resolve_fcall(v).delete_prefix("function ")
          else
            jdat[:rewards][k] = v
          end
        end
      end
    end
    include Serializers

    module Dsl
      def icon item, nbt = nil
        @data[:icon] = [item, nbt]
        self
      end

      [:title, :description, :background].each do |meth|
        define_method(meth) do |value|
          @data[meth] = value
          self
        end
      end

      [:toast, :chat].each do |meth|
        define_method(meth) do |yesno = nil|
          @data[:meth] = yesno.nil? ? true : yesno
          self
        end
      end

      [:hide, :hidden].each do |meth|
        define_method(meth) do |yesno = nil|
          @data[:hidden] = yesno.nil? ? true : yesno
          self
        end
      end

      [:show, :visible].each do |meth|
        define_method(meth) do |yesno = nil|
          hide(yesno.nil? ? false : !yesno)
          self
        end
      end

      [:task, :goal, :challenge].each do |meth|
        define_method(meth) do |*a, **kw, &b|
          @collection.with_parent(self) do
            @collection.send(meth, *a, **kw, &b)
          end
        end
      end

      def children scope = nil, &block
        @collection.with_parent(self) do
          @collection.with_scope(scope) { @collection.instance_eval(&block) }
        end
        self
      end

      def criteria *args, &conditions
        case args.length
        when 1
          @data[:criteria] << [:index, args[0], conditions]
        when 2
          @data[:criteria] << [args[0], args[1], conditions]
        else
          raise ArgumentError, "wrong number of arguments (given #{args.length}, expected 1..2)"
        end
        self
      end

      def reward farg = nil, **kw
        case farg
          when String then kw[:function] = farg
          when Integer then kw[:experience] = farg
        end
        kw[:experience] = kw.delete(:xp) if kw.key?(:xp)
        @data[:reward].merge!(kw)
        self
      end
    end
    include Dsl
  end
end

__END__

using Remid::JsonHelper

#$remid.advancements.defaults(hide: true)

$remid.advancements.task :root, hide: false do
  title "Cramped"
  description "I can't breathe, the walls are consuming me..."
  background :adventure
  icon :chain
  criteria :trigger, :tick

end.task :starter_apple_eaten do
  title "Yummy"
  description "You ate a totally not poisoned apple."
  icon :skeleton_skull
  reward "setup/wait/apple/eaten"

  criteria :eaten, :consume_item do
    item :enchanted_golden_apple
    nbt %{{Tags:["cramped", "poisoned_apple"]}}
  end
end.goal :started do
  title "A Cramped Start"
  description "A fresh beginning..."
  icon :chain
  criteria :landed, :impossible

end.children :radius_milestones do
end



