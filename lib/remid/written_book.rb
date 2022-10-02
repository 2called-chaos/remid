module Remid
  class WrittenBook

    class << self
      attr_reader :_title, :_author, :_pages

      def page name, &block
        @_pages ||= {}
        raise "page with name #{name} already exists" if @_pages[name]
        @_pages[name] = Page.new(name, block)
      end

      def title value = nil, &block
        @_title = block || value.freeze
      end

      def author value = nil, &block
        @_author = block || value.freeze
      end
    end

    def initialize *args, **kw, &block
      @pages = self.class._pages&.dup || []
      @title = self.class._title || "Untitled Book"
      @author = self.class._author || "Unknown"
      init(*args, **kw, &block) if respond_to?(:init)
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

      def initialize(name, builder)
        @name = name
        @builder = builder
        @__page = []
        @__scopes = [JsonHelper::PresentedMinecraftString.new("", merge_on_self: true)]
      end

      def __render book
        @__page.clear
        @__page << ['""']
        @book = book
        @builder.binding.eval("using Remid::JsonHelper")
        instance_eval(&@builder)
        # @__page.pop if @__page.last.empty?
        @__page.delete_if(&:empty?)
        @__page
      ensure
        @book = nil
      end

      def puts *args
        args << nil if args.empty?
        args = args.map{|v| v.nil? ? "" : v}
        args.each do |arg|
          print arg
          __page << []
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
