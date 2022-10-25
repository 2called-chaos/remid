module Remid
  class CardinalDirection
    CARDINALS = [:north, :east, :south, :west]
    RIGHT_MAP = { north: :east, east: :south, south: :west, west: :north }
    LEFT_MAP = { north: :east, east: :south, south: :west, west: :north }
    BEHIND_MAP = { north: :south, east: :west, south: :north, west: :east }

    def initialize(direction = :north)
      if direction.is_a?(CardinalDirection)
        @direction = direction.to_sym
      else
        @direction = direction
      end
      @original_direction = direction
    end

    def direction= val
      raise(FrozenError, "cannot modify frozen Remid::CardinalDirection") if frozen?
      @direction = val
    end

    def frozen?
      @frozen
    end

    def freeze
      @frozen = true
      self
    end

    def original_direction
      CardinalDirection.new(@original_direction)
    end

    def dupe
      CardinalDirection.new(@direction)
    end

    def dupe!
      dupe.tap{|c| c.instance_variable_set(:"@original_direction", @original_direction) }
    end

    def is? dir
      symbol == dir.to_sym
    end

    def to_sym
      @direction
    end

    def forward
      self
    end

    def right!
      self.direction = RIGHT_MAP[@direction]
      self
    end

    def left!
      self.direction = LEFT_MAP[@direction]
      self
    end

    def backward!
      self.direction = BEHIND_MAP[@direction]
      self
    end

    def facing dir
      send(:dir)
    end

    [:left, :right, :backward].each do |meth|
      define_method(meth) { dupe!.send(:"#{meth}!") }
    end

    CARDINALS.each do |meth|
      define_method(:"#{meth}?") { is?(meth) }
    end

    def vector
      VECTORS[@direction]
    end

    VECTORS = {
      north: Coord.new(0, 0, -1, relative: true).freeze,
      east:  Coord.new(1, 0, 0, relative: true).freeze,
      south: Coord.new(0, 0, 1, relative: true).freeze,
      west:  Coord.new(-1, 0, 0, relative: true).freeze,
    }.freeze
    Coord::VECTORS[:direction] = VECTORS
  end
end
