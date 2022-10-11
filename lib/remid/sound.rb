module Remid
  class Sound
    def self.group_from_json file_or_data, namespace
      if file_or_data.is_a?(Hash)
        data = file_or_data
      else
        data = JSON.parse(File.read(file_or_data))
      end
      Group.new.tap do |group|
        data.each do |k, v|
          ns = k.split(".")
          entry = ns.pop
          pointer = group
          while subkey = ns.shift
            pointer[subkey] ||= Group.new
            unless pointer[subkey].is_a?(Group)
              raise "attempted to step into #{subkey} and expected a group but got `#{pointer[subkey].inspect}'"
            end
            pointer = pointer[subkey]
          end
          if pointer[entry].is_a?(Group)
            raise "attempted to add #{entry} but got a group with the same name `#{subkey}'"
          end
          pointer[entry] = Sound.new("#{namespace}:#{k}", {}, group: pointer)
        end
      end
    end

    class Group < OpenStruct
    end

    attr_reader :group

    def initialize(file, _data = {}, group: nil)
      @group = group
      @context = Context.new(self, { file: file }.merge(_data))
    end

    class Context
      def initialize(sound, data = {})
        @sound = sound
        @data = data.reverse_merge({
          pitch: 1.0,
          volume: 1.0,
          min_volume: nil,
          pos: Coord.rel,
          source: :ambient,
          target: "@a",
        })
      end

      def variation key, data = {}, &block
        raise "cannot add variation when sound is not in a group!" unless @sound.group
        if @sound.group[key]
          raise "attempted to add variation `#{key}` but it already exists as `#{@sound.group[key].class}'"
        end
        @sound.group[key] = play(data)
      end

      def play _data = {}
        Context.new(@sound, @data.merge(_data))
      end
      alias_method :dupe, :play

      %i[master music record weather block hostile neutral player ambient voice].each do |meth|
        define_method(meth) { source(meth) }
      end

      [:pitch, :volume, :min_volume, :file, :pos, :source, :target].each do |meth|
        define_method(meth) do |*args|
          if args.empty?
            @data[meth]
          else
            self.send(:"#{meth}=", args.first)
            self
          end
        end

        define_method(:"#{meth}=") do |value|
          @data[meth] = value
        end
      end

      def min mv
        min_volume(mv)
      end

      def at *args, **kw
        if args.first.is_a?(Coord)
          self.pos = args.first
        elsif args.length == 3
          self.pos = Coord.new(*args)
        elsif kw.length > 0
          self.pos = Coord.rel(**kw)
        else
          raise "don't know what to do with #{args} and #{kw}"
        end
        self
      end

      def playfile
        if @data[:file][":"]
          @data[:file]
        else
          unless $remid
            raise "cannot resolve namespace without remid context"
          end
          "#{$remid.function_namespace}:#{@data[:file]}"
        end
      end

      def to_s
        "".tap do |cmd|
          cmd << "playsound"
          cmd << " #{playfile}"
          cmd << " #{@data[:source]}"
          cmd << " #{@data[:target]}"
          cmd << " #{@data[:pos]}"
          cmd << " #{"%.3f" % @data[:volume]}" if @data[:volume] != 1.0 || @data[:pitch] != 1.0 || @data[:min_volume]
          cmd << " #{"%.3f" % @data[:pitch]}" if @data[:pitch] != 1.0 || @data[:min_volume]
          cmd << " #{"%.3f" % @data[:min_volume]}" if @data[:min_volume]
        end
      end
    end

    Context.instance_methods(false).each do |meth|
      define_method(meth) do |*args, **kwargs, &block|
        @context.send(meth, *args, **kwargs, &block)
      end
    end
  end
end
