module Remid
  class Coord
    attr_accessor :x, :y, :z

    def initialize(x, y, z)
      @x, @y, @z = x, y, z
      @original_position = to_a
    end

    def original_position
      Coord.new(*@original_position)
    end

    def to_s
      to_a.join(" ")
    end

    def to_a
      [x, y, z]
    end

    def to_h
      { x: x, y: y, z: z }
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
      Coord.new(x, y, z)
    end

    def delta
      Coord.new(*to_a.map.with_index{|cv, ci| (@original_position[ci] - cv).abs })
    end

    def reset *axis
      if axis.empty?
        set(*@original_position)
      else
        @x = @original_position[0] if axis.include?(:x)
        @y = @original_position[1] if axis.include?(:y)
        @z = @original_position[2] if axis.include?(:z)
      end
      self
    end

    def dupe!
      dupe.tap{|c| c.instance_variable_set(:"@original_position", @original_position) }
    end

    def move(*args, **kw)
      self.x += kw[:x] || args[0] || 0
      self.y += kw[:y] || args[1] || 0
      self.z += kw[:z] || args[2] || 0
      self
    end

    def set(*args, **kw)
      self.x = kw[:x] || args[0] || @x
      self.y = kw[:y] || args[1] || @y
      self.z = kw[:z] || args[2] || @z
      self
    end

    def rel(*args, **kw)
      copy = dupe
      copy.x += kw[:x] || args[0] || 0
      copy.y += kw[:y] || args[1] || 0
      copy.z += kw[:z] || args[2] || 0
      copy
    end

    def at(*args, **kw)
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
            puts "setting ##{ci} from #{before[ci]} to #{cv} (o was #{@original_position[ci]})"
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
  end
end
