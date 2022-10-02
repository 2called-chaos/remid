module Remid
  class Entity
    attr_reader :tags, :type, :data

    def initialize type, *args, **kwargs, &block
      @type = type
      @tags = []
      @data = {}
      init(*args, **kwargs, &block) if respond_to?(:init)
    end

    def init *args, **kwargs, &block
      block&.call(self, *args, **kwargs)
    end

    def instance at, **kwargs, &block
      self.class::Instance.new(self, at, **kwargs).tap {|inst| block&.call(inst) }
    end

    module DSL
      def data_set k, v, x = nil
        _data = data
        if x
          k, v, x = x, k, v
          _data = _data.dig(*x.split(".").map(&:to_sym))
          raise "#{x} can not be resolved in #{data}" unless _data
        end
        _data[k] = v
        self
      end

      def data_del k, x = nil
        _data = data
        if x
          k, v, x = x, k, v
          _data = _data.dig(*x.split(".").map(&:to_sym))
          raise "#{x} can not be resolved in #{data}" unless _data
        end
        _data.delete(k)
        self
      end

      def loot table
        if table == :default
          data_del(:DeathLootTable)
        else
          data_set(:DeathLootTable, table || "minecraft:entities/bat")
        end
      end

      def gravity yesno = true
        if yesno
          data_del(:NoGravity)
        else
          data_set(:NoGravity, true)
        end
      end

      def ai yesno = true
        if yesno
          data_del(:NoAI)
        else
          data_set(:NoAI, true)
        end
      end

      def invulnerable yesno = true
        if yesno
          data_set(:Invulnerable, true)
        else
          data_del(:Invulnerable)
        end
      end

      def silent yesno = true
        if yesno
          data_set(:Silent, true)
        else
          data_del(:Silent)
        end
      end

      def persist yesno = true
        if yesno
          data_set(:PersistenceRequired, true)
        else
          data_del(:PersistenceRequired)
        end
      end

      def persisted *a
        persist(*a)
      end



      # ---------------
      # --- INVERTS ---
      # ---------------
      [:ai, :gravity, :loot, :persist, :persisted, :silent].each do |meth|
        define_method(:"no#{meth}") do |yesno = true|
          send(meth, !yesno)
        end
      end

      def no *what
        what.each do |what_key|
          send(what_key, false)
        end
        self
      end

      def noloot yesno = true
        super(yesno) if yesno
        self
      end

      def vulnerable yesno = true
        invulnerable(!yesno)
      end

      def volatile
        persisted(false)
      end

      def propify!
        persisted.silent.invulnerable.no(:loot, :ai, :gravity)
      end

      def nbt_string _data = nil
        sdat = []
        _data ||= data

        sdat << "Tags:#{tags.map(&:to_s)}"
        _data.each do |k, v|
          case v
          when Array
            case v.first
            when Float
              sdat << "#{k}:[#{v.map{|_v| "#{_v}f" }.join(", ")}]"
            when Integer
              sdat << "#{k}:[#{v.map{|_v| "#{_v}" }.join(", ")}]"
            else
              sdat << "#{k}:#{v.map(&:to_s)}"
            end
          when TrueClass, FalseClass
            sdat << "#{k}:#{v ? "1b" : "0b"}"
          else
            sdat << "#{k}:#{v.inspect}"
          end
        end

        "{#{sdat.join(",")}}"
      end
    end
    include DSL

    class Instance
      include DSL
      attr_reader :entity, :id, :sid, :tags, :data, :pos, :opts

      def initialize(entity, pos, **kwargs)
        @cbuf = kwargs.delete(:cbuf)
        @opts = kwargs
        @opts[:direction] ||= :north
        @entity = entity
        @pos = pos
        @id = $remid.uuid
        @data = entity.data.dup
        @tags = entity.tags.dup
        @tags.unshift($remid.function_namespace)
        @sid = "__remid+#{@id}"
        @tags.unshift(@sid)
        init if respond_to?(:init)
      end

      def facing_rot
        {
          north: [-180.0, 0.0],
          east:  [-90.0, 0.0],
          south: [0.0, 0.0],
          west:  [90.0, 0.0],
        }.freeze[@opts[:direction]]
      end

      def update _data
        cbuf << "data merge entity @e[type=#{entity.type},tag=#{sid}] #{nbt_string(_data)}"
      end

      def cbuf
        $remid.buf(@cbuf)
      end

      def create
        cbuf << "summon #{entity.type} #{pos} #{nbt_string}"
      end

      def summon
        create
      end

      def kill
        cbuf << "kill @e[type=#{entity.type},tag=#{sid}]"
      end
    end
  end
end
