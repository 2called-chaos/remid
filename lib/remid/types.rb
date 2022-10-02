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

    # Support: call a method with the maximum possible amount of arguments but
    # be warned: it's a dirty hack because ruby's arity handling just sucks.
    def __call_method_like_proc method, *args, &block
      method = __method(method) if method.is_a?(::Symbol) || method.is_a?(::String)
      ::Banana::Kernel.__call_method_like_proc(method, *args, &block)
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

    def initialize target, *args, &block
      @target = target
      __call_method_like_proc(:__setup, *args, &block) if __class.__respond_to?(:__setup)
    end

    # send all method calls to the target
    def method_missing(name, *args, &block)
      @target.__send__(name, *args, &block)
    end
  end

  class Float < Proxy
    def to_s
      "#{@target}f"
    end

    def inspect
      "#{@target}f"
    end
  end
end
