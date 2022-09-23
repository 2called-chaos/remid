module Remid
  class Coord
    attr_accessor :x, :y, :z

    def initialize(x, y, z)
      @x, @y, @z = x, y, z
    end

    def to_s
      [x, y, z].join(" ")
    end

    def move(*args, **kw)
      self.dx += kw[:x] || args[0]
      self.dy += kw[:y] || args[1]
      self.dz += kw[:z] || args[2]
      self
    end
  end
end
