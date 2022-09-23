module Remid
  class Coord
    attr_accessor :x, :y, :z

    def initialize(x, y, z)
      @x, @y, @z = x, y, z
    end

    def to_s
      [x, y, z].join(" ")
    end

    def dupe
      Coord.new(x, y, z)
    end

    def move(*args, **kw)
      self.x += kw[:x] || args[0] || 0
      self.y += kw[:y] || args[1] || 0
      self.z += kw[:z] || args[2] || 0
      self
    end

    def rel(*args, **kw)
      copy = dupe
      copy.x += kw[:x] || args[0] || 0
      copy.y += kw[:y] || args[1] || 0
      copy.z += kw[:z] || args[2] || 0
      copy
    end
  end
end
