module Remid
  class WrittenBook

    class << self
      attr_reader :_title, :_author, :_pages

      def page name, &block
        @_pages ||= {}
        raise "page with name #{name} already exists" if @_pages[name]
        @_pages[name] = Page.new(name, block, use_in_binding: true)
      end

      def title value = nil, &block
        @_title = block || value.freeze
      end

      def author value = nil, &block
        @_author = block || value.freeze
      end
    end

    def initialize *args, **kw, &block
      @pages = self.class._pages&.dup || {}
      @title = self.class._title || "Untitled Book"
      @author = self.class._author || "Unknown"
      init(*args, **kw, &block) if respond_to?(:init)
    end

    def page name, &block
      @pages ||= {}
      if block
        raise "page with name #{name} already exists" if @pages[name]
        @pages[name] = Page.new(name, block)
      else
        raise "page with name #{name} does not exist" unless @pages[name]
        pages.index(name)
      end
    end

    def all_pages
      @pages
    end

    def pages
      @pages.keys
    end

    def title value = nil, &block
      @title = block || value.freeze
    end

    def author value = nil, &block
      @author = block || value.freeze
    end

    def give selector = "@a", gen = :original
      pages_content = pages.map do |key|
        rendered = @pages[key].__render(self).join(",")
        rendered.blank? ? '' : "'[#{rendered}]'"
      end

      gen = %i[original copy copy_of_copy tattered].index(gen) || 0

      "give #{selector} written_book".tap do |cmd|
        cmd << "{"
        cmd << %{author:"#{@author.is_a?(Proc) ? @author.call : @author}",}
        cmd << %{title:"#{@title.is_a?(Proc) ? @title.call : @title}",}
        cmd << %{pages:[#{pages_content.join(",")}]}
        cmd << %{,generation:#{gen}} if gen != 0
        cmd << "}"
      end
    end



  # def give selector, type = :original
  #   "give #{selector} written_book".tap do |cmd|
  #     cmd << %{,title:#{title}}
  #     cmd << %{,author:#{author}}
  #     cmd << %{,author:#{generation}}
  #     cmd << %{,display:{Lore:#{lore}}}
  #     cmd << "}"
  #   end
  # end

    class Page
      attr_reader :__page, :book

      def initialize(name, builder, use_in_binding: false)
        @name = name
        @builder = builder
        @use_in_binding = use_in_binding
        @__page = []
        @__scopes = [JsonHelper::PresentedMinecraftString.new("", merge_on_self: true)]
      end

      def __render_safe book
        raise "concurrent render error" if Thread.current[:__book]
        @__page.clear
        @__page << ['""']
        Thread.current[:__book] = @book = book
        yield
        # @__page.pop if @__page.last.empty?
        @__page.delete_if(&:empty?)
        @__page
      ensure
        Thread.current[:__book] = @book = nil
      end

      def __render book
        __render_safe(book) do
          @builder.binding.eval("using Remid::JsonHelper") if @use_in_binding
          instance_eval(&@builder)
        end
      end

      def puts *args
        args << nil if args.empty?
        args = args.flatten.map{|v| v.nil? ? "" : v}
        args.each do |arg|
          print arg
          __page << ['"\\\n"']
        end
      end

      def print *args
        args.each{|a| __page.last << @__scopes.last.wrap(a).merged!(@__scopes.last.opts) }
      end

      def scope
        @__scopes.push(@__scopes.last.merged!)
        yield
      ensure
        @__scopes.pop
      end

      JsonHelper::PresentedMinecraftString.instance_methods(false).each do |meth|
        define_method(meth) do |*args, **kw, &block|
          @__scopes.last.send(meth, *args, **kw, &block)
        end
      end
    end
  end
end
