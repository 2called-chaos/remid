module Remid
  class BasicProxy < BasicObject
    # <ActiveSupport::ProxyObject>
    undef_method :==
    undef_method :equal?

    # Let the proxy class raise exceptions
    def raise(*args)
      ::Object.send(:raise, *args)
    end
    # </ActiveSupport>

    # Identify proxy object
    # @note You need to call this method and rescue NoMethodError as respond_to? will hit the target not the proxy object!
    def __banana_basicproxy
      self
    end

    # Get the actual proxy class
    def __class
      (class << self; self; end).superclass
    end

    # Support: method() mimic function
    def __method method, on = self
      __class.instance_method(method.to_sym).bind(self)
    end

    # Get the proxy meta class
    def self.__metaclass__
      class << self; self; end
    end

    # Support: respond_to?() mimic function
    def self.__respond_to? method
      self.instance_methods.include?(method.to_sym)
    end
  end

  class Proxy < BasicProxy
    # target accessor for @target
    def __target
      @target
    end

    # preserve proxy when using tap
    def tap
      yield self if ::Kernel.block_given?
      self
    end

    protected

    def initialize target, *args, **kwargs, &block
      @target = target
      __setup(*args, **kwargs, &block) if __class.__respond_to?(:__setup)
    end

    # send all method calls to the target
    def method_missing(name, *args, &block)
      @target.__send__(name, *args, &block)
    end
  end

  class FreezableProxy < Proxy
    def initialize *args, **kwargs, &block
      @frozen = false
      super
    end

    def frozen?
      @frozen
    end

    def freeze
      @frozen = true
      self
    end
  end

  class Float < Proxy
    def to_s
      "#{@target}f"
    end

    def inspect
      to_s
    end
  end

  class Angle < FreezableProxy
    def to_s
      "#{@target}f"
    end

    def inspect
      to_s
    end

    def dupe
      Angle.new(@target)
    end

    [:invert, :right, :left].each do |meth|
      define_method(meth) do |*args, **kwargs|
        Angle.new(@target).send(:"#{meth}!", *args, **kwargs)
      end
    end

    def invert!
      raise "cannot modify frozen Remid::Angle" if frozen?
      right(180)
      self
    end

    def right! ang
      raise "cannot modify frozen Remid::Angle" if frozen?
      @target = (@target + ang) % 360
      self
    end

    def left! ang
      raise "cannot modify frozen Remid::Angle" if frozen?
      right(-ang)
      self
    end
  end

  class AngleGroup < FreezableProxy
    def initialize(*angles)
      @target = angles.map{|ang| Angle.new(ang) }
    end

    def freeze
      super
      @target.freeze
    end

    def deep_freeze
      @target.each(&:freeze)
      freeze
    end

    [:invert, :left, :right].each do |meth|
      define_method(meth) do |*args, **kwargs|
        @target.map{|v| v.send(meth, *args, **kwargs) }
      end
      define_method(:"#{meth}!") do |*args, **kwargs|
        raise "cannot modify frozen Remid::Angle" if frozen?
        @target = @target.map{|v| v.dupe.send(meth, *args, **kwargs) }
      end
    end
  end

  class NbtHash < Proxy
    def self.kv_to_str k, v
      case v
      when ::Array
        case v.first
        when ::Symbol
          "#{k}:#{v.map(&:to_s)}"
        else
          "#{k}:#{v}"
        end
      when ::TrueClass, ::FalseClass
        "#{k}:#{v ? "1b" : "0b"}"
      else
        "#{k}:#{v.inspect}"
      end
    end

    def self.h_to_str h
      r = h.map {|k, v| kv_to_str(k, v) }
      "{#{r.join(", ")}}"
    end

    def to_s
      NbtHash.h_to_str(@target)
    end

    def inspect
      to_s
    end
  end
end
