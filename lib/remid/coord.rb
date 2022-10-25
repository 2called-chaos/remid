module Remid
  class Coord
    def self.rel *args, **kwargs
      if args.length == 1 && args.first.is_a?(Coord)
        args = args.first.to_a
      end
      args << 0 while args.length < 3
      args[0] = kwargs[:x] if kwargs.key?(:x)
      args[1] = kwargs[:y] if kwargs.key?(:y)
      args[2] = kwargs[:z] if kwargs.key?(:z)
      new(*args, facing: kwargs[:facing], relative: true)
    end
    attr_reader :x, :y, :z

    def initialize(x, y, z, facing: :north, relative: false)
      @relative = relative
      @facing = CardinalDirection.new(facing)
      @frozen = false
      @x, @y, @z = x, y, z
      @original_position = to_a
    end

    def frozen?
      @frozen
    end

    def freeze
      @frozen = true
      self
    end

    [:x, :y, :z, :facing].each do |axe|
      define_method(:"#{axe}=") do |val|
        raise(FrozenError, "cannot modify frozen Remid::Coord") if frozen?
        instance_variable_set(:"@#{axe}", val)
      end
    end

    def facing! dir
      @facing = CardinalDirection.new(dir)
      self
    end

    def facing *args
      if args.empty?
        @facing
      else
        dupe.facing!(*args)
      end
    end

    def original_position
      Coord.new(*@original_position, relative: @relative, facing: @facing)
    end

    def to_sel *axis
      axis = [:x, :y, :z] if axis.empty?
      axis.map do |axe|
        "#{axe}=#{send(axe)}"
      end.join(",")
    end

    def to_dim *axis
      axis = [:x, :y, :z] if axis.empty?
      axis.map do |axe|
        "d#{axe}=#{send(axe)}"
      end.join(",")
    end

    def min coord
      at([x, coord.x].min, [y, coord.y].min, [z, coord.z].min)
    end

    def max coord
      at([x, coord.x].max, [y, coord.y].max, [z, coord.z].max)
    end

    def to_s
      @relative ? to_a.map{|v| v.zero? ? "~" : "~#{v}" }.join(" ") : to_a.join(" ")
    end

    def to_a
      [x, y, z]
    end

    def to_h
      { x: x, y: y, z: z }
    end

    def distance coord
      Math.sqrt(distance_to_squared(coord))
    end

    def distance_to_squared coord
      dx = self.x - coord.x
      dy = self.y - coord.y
      dz = self.z - coord.z
      dx * dx + dy * dy + dz * dz
    end

    def manhattan_distance corrd
      (self.x - coord.x).abs + (self.y - coord.y).abs + (self.z - coord.z).abs
    end

    def * _t
      _t.times.map{ to_s }.join(" ")
    end

    def setblock block
      if block.is_a?(Hash)
        "fill #{to_s} #{to_s} #{block.values.first} replace #{block.keys.first}"
      else
        "setblock #{to_s} #{block}"
      end
    end

    def dupe
      Coord.new(x, y, z, relative: @relative, facing: @facing)
    end

    def delta d_to
      diff(d_to).abs!
    end

    def diff d_to
      if d_to.is_a?(Coord)
        Coord.new(*to_a.map.with_index{|cv, ci| d_to.to_a[ci] - cv })
      elsif d_to
        Coord.new(*to_a.map.with_index{|cv, ci| d_to[ci] - cv })
      else
        Coord.new(*to_a.map.with_index{|cv, ci| @original_position[ci] - cv })
      end
    end

    def reset *axis
      if axis.empty?
        set(*@original_position)
      else
        self.x = @original_position[0] if axis.include?(:x)
        self.y = @original_position[1] if axis.include?(:y)
        self.z = @original_position[2] if axis.include?(:z)
      end
      self
    end

    def execute
      "execute positioned #{to_s}"
    end

    def dupe!
      dupe.tap{|c| c.instance_variable_set(:"@original_position", @original_position) }
    end

    def invert
      dupe.invert!
    end

    def invert!
      self.x *= -1
      self.y *= -1
      self.z *= -1
      self
    end

    def _prep_args args
      if VECTORS[:direction].key?(args.first)
        return VECTORS[:direction][args.first].mult(args.second).to_a
      end

      if args.length == 1 && args.first.is_a?(Coord)
        return args.first.to_a
      end

      args
    end

    def _resolve_relative kw, target
      kw[:r] = -kw[:l] if kw.key?(:l)
      kw[:f] = -kw[:b] if kw.key?(:b)

      if kw[:r]
        fvec = @facing.right.vector.mult(kw[:r])
        target.x += fvec.x
        target.z += fvec.z
      end

      if kw[:f]
        fvec = @facing.vector.mult(kw[:f])
        target.x += fvec.x
        target.z += fvec.z
      end

      target
    end

    def abs
      dupe.abs!
    end

    def abs!
      self.x = self.x.abs
      self.y = self.y.abs
      self.z = self.z.abs
      self
    end

    def move(*args, **kw)
      args = _prep_args(args)
      self.x += kw[:x] || args[0] || 0
      self.y += kw[:y] || args[1] || 0
      self.z += kw[:z] || args[2] || 0
      _resolve_relative(kw, self)
    end

    def set(*args, **kw)
      args = _prep_args(args)
      self.x = kw[:x] || args[0] || @x
      self.y = kw[:y] || args[1] || @y
      self.z = kw[:z] || args[2] || @z
      self
    end

    def rel(*args, **kw)
      args = _prep_args(args)
      copy = dupe
      copy.x += kw[:x] || args[0] || 0
      copy.y += kw[:y] || args[1] || 0
      copy.z += kw[:z] || args[2] || 0

      _resolve_relative(kw, copy)
    end

    def mult! *xargs, **kw
      args = _prep_args(xargs)
      args << args.first while args.length < 3
      self.x = self.x * (kw[:x] || args[0] || 1)
      self.y = self.y * (kw[:y] || args[1] || 1)
      self.z = self.z * (kw[:z] || args[2] || 1)
      self
    end

    def mult *args, **kw
      dupe.mult!(*args, **kw)
    end

    def at(*args, **kw)
      args = _prep_args(args)
      copy = dupe
      copy.x = kw[:x] || args[0] || @x
      copy.y = kw[:y] || args[1] || @y
      copy.z = kw[:z] || args[2] || @z
      copy
    end

    def _alter_original_if_axis_changed
      before = to_a
      yield.tap do
        to_a.each_with_index do |cv, ci|
          if before[ci] != cv
            #puts "setting ##{ci} from #{before[ci]} to #{cv} (o was #{@original_position[ci]})"
            @original_position[ci] = cv
          end
        end
      end
    end

    def move!(*args, **kw)
      _alter_original_if_axis_changed { move(*args, **kw) }
    end

    def set!(*args, **kw)
      _alter_original_if_axis_changed { set(*args, **kw) }
    end


    VECTORS = {}
  end
end
