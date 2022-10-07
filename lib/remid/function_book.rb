module Remid
  using JsonHelper

  class FunctionBook < WrittenBook
    include FunctionParser::Resolvers
    attr_accessor :exception
    attr_reader :warnings, :context

    LPP = 13

    def init context
      @context = context
      @warnings = []
      @title = "#{$remid.function_namespace} functions"
      @author = "Remid::FunctionBook"
    end

    def render_pages_for functions
      state ||= {
        page_map: {},
        pages: {},
        lines: [],
        page_no: 1,
      }
      _render_pages_for(functions.keys, state)
      state[:pages].each_with_index do |(pn, pg), i|
        puts "initing #{pn}"
        page(pn) { puts pg }
      end
      state[:pages].each_with_index do |(pn, pg), i|
        puts "rendering #{pn}"
        @pages[pn].__render_safe(self) do
          # resolve delayed calls (page resolve)
          pg.each do |li|
            if li.is_a?(JsonHelper::PresentedMinecraftStringBase)
              li.finalize_delayed!
            end
          end
        end
      end
    end

    def _render_pages_for functions, state = nil, scope = []
      functions = functions - ["__remid/fnbook"]
      top_level = functions.reject{|v| v.include?("/") }.sort
      children = (functions - top_level).sort.group_by{|v| v.split("/", 2)[0] }

      _render_pages_for_sub(top_level, children, state, scope)
      children.each do |k, v|
        _render_pages_for(v.map{|x| x.delete_prefix("#{k}/".freeze) }, state, scope + [k])
      end
    end

    def _render_pages_for_sub top_level, children, state, scope = []
      sub_i = 1
      all_keys = (top_level + children.keys).sort
      total_pages = (all_keys.length.to_f / (LPP - 1).to_f).ceil
      _render_page_head(state, scope, sub_i, total_pages)

      all_keys.each do |fnc|
        if state[:lines].length >= LPP
          _render_page_commit(state, scope.join("/"), sub_i)
          sub_i += 1
          _render_page_head(state, scope, sub_i, total_pages)
        end
        if top_level.include?(fnc) && !(children.key?(fnc) && !state[:page_map]["#{fnc}/"])
          sx = "./#{fnc}".light_purple.hover("run #{fnc}").click("/" + (scope + [fnc]).join("/"))
          state[:lines] << sx
        elsif children.key?(fnc)
          sx = "./#{fnc}/".blue.hover("go to #{fnc}").click(page: :"#{(scope + [fnc]).join("/")}_1")
          sx << " (#{children[fnc].length})".gray
          state[:lines] << sx
          fnc = "#{fnc}/"
        else
          raise "how did we get here?!?"
        end
        state[:page_map][(scope + [fnc]).join("/")] = state[:page_no]
      end

      _render_page_commit(state, scope.join("/"), sub_i) if state[:lines].any?
    end

    def _render_page_head state, scope, sub_i, total_pages
      x = "#".red
      x = x.hover("Go to index").click(page: 0) unless scope.empty?
      if scope.any?
        x << "/".dark_gray
        so_far = []
        scope.each_with_index do |s, si|
          so_far << s
          if si == scope.length - 1
            x << "#{s}".gold
          else
            why = state[:page_map][so_far.join("/") + "/"]
            x << "#{s}".dark_blue.hover("go to #{s}").click(page: why)
            x << "/".dark_gray
          end
          "#{s}".color(si == scope.length - 1 ? :gold : :dark_blue)
        end
        state[:page_map][so_far.join("/") + "/"] = state[:page_no]
      else
        x << " INDEX".gold
      end

      if total_pages > 1
        x << " (#{sub_i}/#{total_pages})".gray
      end

      state[:lines] << x
    end

    def _render_page_commit state, scope, sub_i
      state[:pages][:"#{scope}_#{sub_i}"] = state[:lines]
      state[:page_no] += 1
      state[:lines] = []
    end

    def as_string
      give("@s")
    end

    def result_buffer
      [as_string]
    end

    def finalize_buffer!
      raise "concurrent parse error" if Thread.current[:fparse_rbuf]
      Thread.current[:fparse_inst] = self
      Thread.current[:fparse_rbuf] = rbuf = []
      Thread.current[:fparse_cbuf] = cbuf = []
      Thread.current[:fparse_wbuf] = @warnings
      render_pages_for(@context.functions)
    ensure
      Thread.current[:fparse_inst] = nil
      Thread.current[:fparse_rbuf] = nil
      Thread.current[:fparse_cbuf] = nil
      Thread.current[:fparse_wbuf] = nil
    end
  end
end
