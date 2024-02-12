module Remid
  class AdvancementManager < Hash
    attr_reader :parents, :scopes, :context

    def initialize context
      @context = context
      @parents = []
      @scopes = []
      @defaults = {
        toast: true,
        chat: true,
        hidden: true,
      }
    end

    def defaults to_merge = {}
      @defaults.merge!(to_merge)
    end

    def [] key
      super(key.to_s)
    end

    def add key, type = :task, **kw, &block
      rkey = key.to_s
      rkey = (@scopes + [rkey]).join("/")
      raise "duplicate advancement error #{rkey} already taken" if self[rkey]
      callkw = @defaults
      callkw[:parent] = @parents.last if @parents.any?
      callkw = callkw.merge(kw)
      self[rkey] = Advancement.new(self, key.to_s, type, **callkw, &block)
    end

    def task key, **kw, &block
      add(key, :task, **kw, &block)
    end

    def goal key, **kw, &block
      add(key, :goal, **kw, &block)
    end

    def challenge key, **kw, &block
      add(key, :challenge, **kw, &block)
    end

    def with_parent parent
      @parents << parent
      yield
    ensure
      @parents.pop if @parents.last == parent
    end

    def with_scope scope
      @scopes << scope if scope
      yield
    ensure
      @scopes.pop if scope && @scopes.last == scope
    end
  end
end
