module Remid
  class SeekableStringIO < StringIO
    def peek *args
      read(*args).tap{|rs| self.pos -= rs&.bytesize || 0 }
    end

    def readif what
      if what.is_a?(Array)
        return what.detect{|x| readif(x) }
      end

      read_string = read(what.bytesize)
      return false if read_string.nil?
      if read_string == what
        return read_string
      else
        self.pos -= read_string.bytesize
        return false
      end
    end

    def read_while what
      count = 0
      count += 1 while readif(what)
      count
    end
  end

  class FunctionParser
    attr_reader :warnings, :payload, :context, :cbuf, :fname
    attr_accessor :exception

    SPACES = [" ", "\t"].freeze
    ENCLOSERS = ["[", "]", "{", "}"].freeze
    T_SPACE = " ".freeze
    T_EVAL = "#~~".freeze
    T_EVAL_BEGIN = "__BEGIN__".freeze
    T_EVAL_END = "__END__".freeze
    T_EVAL_APPEND = "#~<".freeze
    T_BLOCK_OPEN = "#~[".freeze
    T_BLOCK_CLOSE = "#~]".freeze
    T_COMMENT = "#".freeze
    T_GT = ">".freeze
    T_DOUBLE_GT = ">>".freeze
    T_TRIPLE_GT = ">>>".freeze
    T_BANG = "!".freeze
    T_GT_BANG = ">!".freeze
    T_GTEQ = ">=".freeze
    T_LT = "<".freeze
    T_DOUBLE_LT = "<<".freeze
    T_TRIPLE_LT = "<<<".freeze
    T_LTEQ = "<=".freeze
    T_SLASH = "/".freeze
    T_BACKSLASH = "\\".freeze
    T_NSSEP = ":".freeze

    def initialize context, fname, payload, src, a_binding = nil, skip_indent: 0, li_offset: 0
      @context = context
      @payload = payload
      @a_binding = a_binding # || get_binding
      @src = @rsrc = src
      rt = @context.relative_target&.to_s
      if rt && @src.to_s.start_with?(rt)
        @rsrc = Pathname.new("." << @rsrc.to_s[rt.length..-1])
      end
      @fname = fname
      @warnings = []
      @indent_per_level = 1
      @skip_indent = skip_indent
      @li_offset = li_offset
    end

    def get_binding
      binding
    end

    [:capture].each do |meth|
      define_method(meth) do |*a, **kw, &b|
        context.send(meth, *a, **kw, &b)
      end
    end

    def anonymous_function
      buf = []
      yield(buf)
      fkey = "#{@fname}/__anon_#{@li_no}"
      xout = _execute_sub(buf, concat: false, as_func: true)
      fnc = @context.__remid_register_anonymous_function(fkey, xout)
      "#{@context.function_namespace}:#{fnc}"
    end

    def parse
      raise "concurrent parse error" if Thread.current[:fparse_rbuf]
      @li_no = @li_offset
      @cbuf = []
      @rbuf = []
      @state = {}
      @state[:block_indent] = 0
      @state[:prev_indent] = 0
      @state[:indent] = 0
      @state[:scoped_indent] = 0
      @state[:block_buffer] = []
      @state[:eval_block] = []
      @state[:block_header] = nil
      @state[:block_footer] = nil
      @state[:in_eval_block] = false

      buf = payload.split("\n", -1)

      Thread.current[:fparse_rbuf] = @rbuf
      Thread.current[:fparse_cbuf] = @cbuf
      Thread.current[:fparse_wbuf] = @warnings

      while raw_line = buf.shift
        @li_no += 1
        @raw_line = raw_line
        @line = SeekableStringIO.new(@raw_line)
        #puts "#{@li_no}\t #{@line.peek}"

        # skip indent (subs)
        (@skip_indent * @indent_per_level).times do
          @line.readif(SPACES)
        end

        if @state[:in_eval_block]
          if @line.peek == T_EVAL_END
            @state[:in_eval_block] = false
            obj = self.clone
            obj.instance_variable_set(:"@__clone_parent", self)
            def obj.out
              @__clone_parent.cbuf
            end
            obj.instance_eval(@state[:eval_block].join("\n"))
            #puts @state[:eval_block]
            @state[:eval_block].clear
          else
            @state[:eval_block] << @line.read
          end
          next
        elsif @line.peek == T_EVAL_END
          raise "unexcepected T_EVAL_END #{T_EVAL_END} in #{@rsrc}:#{@li_no}"
        end

        # indent
        cindent = @line.read_while(SPACES)
        @state[:prev_indent] = @state[:indent]
        @state[:indent] = cindent
        @state[:indent_increased] = @state[:prev_indent] < @state[:indent]
        @state[:indent_decreased] = @state[:prev_indent] > @state[:indent]
        @state[:scoped_indent] += 1 if @state[:indent_increased]
        @state[:scoped_indent] -= 1 if @state[:indent_decreased]

        if @state[:in_anonymous] && !(@line.peek(T_TRIPLE_GT.length) == T_TRIPLE_GT && @state[:indent] == 0)
          @state[:anon_buffer] << @raw_line
          next
        end

        if @state[:in_ral] && !(@line.peek(T_DOUBLE_GT.length) == T_DOUBLE_GT && @state[:indent] == 0)
          @state[:ral_buffer] << @raw_line
          next
        end

        if @state[:block_indent] != 0
          if @line.peek(T_BLOCK_OPEN.length) == T_BLOCK_OPEN
            @state[:block_indent] += 1
            @state[:block_buffer] << @raw_line
            next
          elsif @line.peek(T_BLOCK_CLOSE.length) == T_BLOCK_CLOSE && @state[:block_indent] > 1
            @state[:block_indent] -= 1
            @state[:block_buffer] << @raw_line
            next
          elsif !(@line.peek(T_BLOCK_CLOSE.length) == T_BLOCK_CLOSE)
            @state[:block_buffer] << @raw_line
            next
          end
        end

        if @line.peek.empty?
          @cbuf << @line.read
        elsif @line.readif(T_EVAL_BEGIN)
          @state[:in_eval_block] = true
          @state[:eval_block_lino] = @li_no
        elsif @line.readif(T_EVAL_APPEND)
          _l_eval(append:true)
        elsif @line.readif(T_EVAL)
          _l_eval
        elsif @line.readif(T_BLOCK_OPEN)
          _l_block_open
        elsif @line.readif(T_BLOCK_CLOSE)
          _l_block_close
        elsif @line.peek(1) == T_COMMENT && @line.peek(2) != "#\{"
          _l_comment
        elsif @line.readif(T_TRIPLE_GT)
          _l_anon_close
        elsif @line.readif(T_DOUBLE_GT)
          _l_ral_close
        elsif @line.readif(T_GT_BANG)
          _l_scoreboard_op_helper
        elsif @line.readif(T_GT)
          _l_scoreboard_helper
        elsif @line.readif(T_SLASH)
          _l_command_helper
        else
          if !@cbuf.last || @state[:indent] == @state[:block_indent] * @indent_per_level && !ENCLOSERS.include?(@line.peek(1))
            @cbuf << process_interpolations(@line.read)
          else
            @cbuf.last << T_SPACE << process_interpolations(@line.read)
          end

          # anonymous functions
          _i_anon_open if @cbuf.last&.end_with?(T_TRIPLE_LT)

          # repeat-a-line
          _i_ral_open if @cbuf.last&.end_with?(T_DOUBLE_LT)
        end
      end

      raise "OpenRAL: expected >> but found EOF (opened `#{@state[:ral_entry]}' in #{@rsrc}:#{@state[:ral_lino]})" if @state[:in_ral]
      raise "OpenAnonymous: expected >>> but found EOF (opened `#{@state[:anon_entry]}' in #{@rsrc}:#{@state[:anon_lino]})" if @state[:in_anonymous]
      raise "OpenEvalBlock: expected __END__ but found EOF (opened in #{@rsrc}:#{@state[:eval_block_lino]})" if @state[:in_eval_block]

      commit_cbuf
    ensure
      # if Thread.current == Thread.main
        Thread.current[:fparse_rbuf] = nil
        Thread.current[:fparse_cbuf] = nil
        Thread.current[:fparse_wbuf] = nil
      # end
    end

    def commit_cbuf
      @rbuf << @cbuf.shift while @cbuf.length > 0
      @rbuf
    end

    def finalize_buffer!
      old_rbuf = @rbuf.dup
      @rbuf.clear

      # call delayed procs
      old_rbuf.each do |rbe|
        if rbe.is_a?(Proc)
          rbe.call(tmpcbuf = [])
          # tmpcbuf = tmpcbuf.reverse
          @rbuf << tmpcbuf.shift while tmpcbuf.length > 0
        else
          @rbuf << rbe
        end
      end

      # autofix trailing commas
      if context.opts.autofix_trailing_commas
        @rbuf.each_with_index do |cl, rbi|
          unless cl.start_with?("#")
            while ci = cl.index(/,(\s+[\}\]])/)
              unless context.opts.autofix_trailing_commas == :silent
                warnings << "autofix: removed trailing comma in output-line #{rbi + 1}:#{ci} `#{cl[([ci-10, 0].max)..(ci + 10)]}' of #{@rsrc}"
              end
              cl.sub!(/,(\s+[\}\]])/, '\1')
            end
          end
        end
      end
    end

    def _execute_sub input_buffer, header: nil, footer: nil, concat: true, concat_warnings: nil, finalize: false, as_func: false
      concat_warnings = concat if concat_warnings.nil?
      proc do
        a_binding = binding
        a_binding.local_variable_set(:a_context, @context)
        a_binding.local_variable_set(:a_src, @src)
        a_binding.local_variable_set(:a_fname, @fname)
        a_binding.local_variable_set(:a_buffer, input_buffer)
        a_binding.local_variable_set(:a_li_offset, @li_no - input_buffer.length - (header ? 1 : 0) - 1)
        a_binding.local_variable_set(:a_skip_indent, @skip_indent + 1)
        a_binding.local_variable_set(:x_binding, @a_binding)
        a_binding.local_variable_set(:a_finalize_buffer, finalize)
        a_binding.local_variable_set(:a_as_func, as_func)

        to_eval = []
        to_eval << %q{parent_thread = Thread.current}
        to_eval <<  %{#{header}} if header
        to_eval << %q{  s_binding = binding}
        to_eval << %q{  if x_binding}
        to_eval << %q{    (x_binding.local_variables - s_binding.local_variables).each do |x|}
        to_eval << %q{      s_binding.local_variable_set(x, x_binding.local_variable_get(x))}
        to_eval << %q{    end}
        to_eval << %q{  end}
        #to_eval << %q{  parent_thread = Thread.main unless parent_thread[:fparse_cbuf]}
        to_eval << %q{  thr = Thread.new do}
        to_eval << %q{    fp = FunctionParser.new(a_context, a_fname, a_buffer.join("\n"), a_src, s_binding, skip_indent: a_skip_indent, li_offset: a_li_offset)}
        #to_eval << %q{    puts ">----------------------"}
        #to_eval << %q{    puts a_buffer.inspect}
        #to_eval << %q{    puts "=---------------------"}
        #to_eval << %q{    puts fp.result_buffer.inspect}
        #to_eval << %q{    puts "<---------------------"}
        #to_eval << %q{    puts }
        #to_eval << %q{    puts }
        #to_eval << %q{    puts parent_thread == Thread.main }
        #to_eval << %q{    puts parent_thread[:fparse_cbuf].inspect }
        #to_eval << %q{    puts }
        to_eval << %q{    parent_thread[:fparse_cbuf] = parent_thread[:fparse_cbuf].concat fp.result_buffer.dup} if concat
        to_eval << %q{    parent_thread[:fparse_wbuf] = parent_thread[:fparse_wbuf].concat fp.warnings} if concat_warnings
        to_eval << %q{    fp.result_buffer } unless concat
        to_eval << %q{    fp.finalize_buffer! if a_finalize_buffer }
        to_eval << %q{    Thread.current[:result] = a_as_func ? fp : fp.result_buffer.join("\n") }
        to_eval << %q{  end}
        to_eval << %q{  thr.join}
        to_eval << %q{  thr[:result]}
        to_eval <<  %{#{footer}} if footer
        eval(to_eval.join("\n"), a_binding)
      end.call
    end

    def _i_anon_open
      @state[:in_anonymous] = true
      @state[:anon_entry] = @cbuf.pop.delete_suffix(T_TRIPLE_LT)
      @state[:anon_lino] = @li_no
      @state[:anon_buffer] = []
    end

    def _i_ral_open
      @state[:in_ral] = true
      @state[:ral_entry] = @cbuf.pop.delete_suffix(T_DOUBLE_LT)
      @state[:ral_lino] = @li_no
      @state[:ral_buffer] = []
    end

    def _l_ral_close
      if !@state[:in_ral]
        raise "unexcepected RAL close >> in #{@rsrc}:#{@li_no}"
      end
      @state.delete(:in_ral)

      if @state[:ral_buffer].empty?
        @state.delete(:ral_buffer)
        @state.delete(:ral_entry)
        return
      end

      a_entry = @state.delete(:ral_entry)
      a_buffer = @state.delete(:ral_buffer)
      xout = _execute_sub(a_buffer, concat: false, concat_warnings: true, finalize: true)
      xout.split("\n").each do |l|
        if l.blank?
          @cbuf << l
        else
          @cbuf << (a_entry + l)
        end
      end
    end

    def _l_anon_close
      if !@state[:in_anonymous]
        raise "unexcepected AnonymousFunction close >>> in #{@rsrc}:#{@li_no}"
      end
      @state.delete(:in_anonymous)

      if @state[:anon_buffer].empty?
        @state.delete(:anon_buffer)
        @state.delete(:anon_entry)
        return
      end

      a_entry = @state.delete(:anon_entry)
      a_buffer = @state.delete(:anon_buffer)
      a_lino = @state.delete(:anon_lino)
      fkey = "#{@fname}/__anon_#{a_lino}"
      xout = _execute_sub(a_buffer, concat: false, as_func: true)
      fnc = @context.__remid_register_anonymous_function(fkey, xout)
      @cbuf << a_entry + "function #{@context.function_namespace}:#{fnc}"
    end

    def _l_eval append: false
      @line.read_while(SPACES) # padding
      eval_pos = @line.pos
      to_eval = @line.read
      begin
        eres = eval(to_eval, @a_binding)
        @cbuf.push(eres.to_s) if append
        eres
      rescue Exception => ex
        warn ">> in #{@src || "unknown"}:#{@li_no}:#{eval_pos}"
        warn ">>   #{@raw_line}"
        raise(ex)
      end
    end

    def _l_block_open
      @line.read_while(SPACES) # padding
      # collect till end, evaluate and add to rbuf
      @state[:block_indent] += 1
      #puts "open #{@state[:block_indent]}"
      if @state[:block_indent] == 1
        @state[:block_header] = @line.read
        commit_cbuf
      end
    end

    def _l_block_close
      if @state[:block_indent] == 0
        raise "unexcepected T_BLOCK_CLOSE #{T_BLOCK_CLOSE} in #{@rsrc}:#{@li_no}"
      end
      @line.read_while(SPACES) # padding
      #puts "close #{@state[:block_indent]}"
      # marks block end
      @state[:block_indent] -= 1

      if @state[:block_indent] == 0
        @state[:block_footer] = @line.read

        a_buffer = @state[:block_buffer].dup.freeze
        @state[:block_buffer].clear
        _execute_sub(a_buffer, header: @state.delete(:block_header), footer: @state.delete(:block_footer))
      end
    end

    def _l_comment
      if @state[:indent] == @state[:block_indent] * @indent_per_level
        @cbuf << @line.read
      else
        # inline comment, ignore
      end
    end

    def _l_scoreboard_op_helper
      @line.read_while(SPACES) # padding
      instruct = process_interpolations(@line.read)
      @cbuf << resolve_scoreboard_op_instruct(instruct)
    end

    def _l_scoreboard_helper
      @line.read_while(SPACES) # padding
      instruct = process_interpolations(@line.read)
      @cbuf << resolve_scoreboard_instruct(instruct)
    end

    def _l_command_helper
      fcall = process_interpolations(@line.read)
      @cbuf << resolve_fcall(fcall)
    end

    def process_interpolations str
      pointer = 0
      r = []
      depth = 0
      in_interp = false
      ibuf = ""
      #puts str
      while pointer < str.length
        #puts "p:#{pointer} d:#{depth} ii:#{in_interp} ib:#{ibuf}"
        if in_interp
          if str[pointer] == "{"
            if str[pointer - 1] == T_BACKSLASH
              ibuf.pop # remove backslash
            else
              depth += 1
            end
            ibuf << str[pointer]
          elsif str[pointer] == "}"
            if str[pointer - 1] == T_BACKSLASH
              ibuf.pop # remove backslash
            elsif depth > 0
              depth -= 1
            else
              raise "unmatched brackets"
            end

            if depth == 0
              in_interp = false

              if ibuf[0] == T_GT && ibuf[1] == T_BANG
                sp = 1
                sp += 1 while SPACES.include?(ibuf[sp])
                r << resolve_scoreboard_instruct(ibuf[sp..-1])
              elsif ibuf[0] == T_GT
                sp = 1
                sp += 1 while SPACES.include?(ibuf[sp])
                r << resolve_scoreboard_instruct(ibuf[sp..-1])
              elsif ibuf[0] == T_SLASH
                r << resolve_fcall(ibuf[1..-1])
              else
                #puts Rainbow(ibuf).red
                r << ("#{eval(ibuf, @a_binding)}")
              end
            else
              ibuf << str[pointer]
            end
          else
            ibuf << str[pointer]
          end
        else
          if str[pointer] == "#" && str[pointer + 1] == "{"
            if str[pointer - 1] == T_BACKSLASH
              r.pop # remove backslash
            else
              ibuf.clear
              pointer += 2
              depth += 1
              in_interp = true
              next
            end
          end
          r << str[pointer]
        end
        pointer += 1
      end
      raise "unmatched interpolation" if depth > 0
      r.join("")
    rescue Exception => ex
      raise "#{ex.class}: #{ex.message} in #{@rsrc}:#{@li_no}"
    end

    def resolve_objective str
      if str.start_with?("/")
        str[1..-1]
      else
        scoped_key = "#{@context.scoreboard_namespace}_#{str}"
        unless @context.objectives[scoped_key]
          @warnings << "referencing undefined scoreboard objective `#{scoped_key}' in #{@rsrc}:#{@li_no}"
        end
        scoped_key
      end
    end

    def resolve_scoreboard_instruct instruct
      if m = instruct.match(/^([^\s]+)\s+([^\s]+)\s+(=|\+=|\-=)\s+([\-\+\d]+)$/i)
        # > $objective $player = VAL
        # > $objective $player += VAL
        # > $objective $player -= VAL
        case m[3]
        when "="
          "scoreboard players set #{m[2]} #{resolve_objective(m[1])} #{m[4]}"
        when "+="
          "scoreboard players add #{m[2]} #{resolve_objective(m[1])} #{m[4]}"
        when "-="
          "scoreboard players remove #{m[2]} #{resolve_objective(m[1])} #{m[4]}"
        end
      elsif m = instruct.match(/^([^\s]+)\s+([^\s]+)\s+(reset|enable)$/i)
        # > $objective $player reset
        # > $objective $player enable
        "scoreboard players #{m[3]} #{m[2]} #{resolve_objective(m[1])}"
      elsif m = instruct.match(/^([^\s]+)\s+([^\s]+)\s+(\+\+|\-\-)$/i)
        # > $objective $player ++
        # > $objective $player --
        case m[3]
        when "++"
          "scoreboard players add #{m[2]} #{resolve_objective(m[1])} 1"
        when "--"
          "scoreboard players remove #{m[2]} #{resolve_objective(m[1])} 1"
        end
      elsif m = instruct.match(/^([^\s]+)\s+([^\s]+)$/i)
        # > $objective $player
        "scoreboard players get #{m[2]} #{resolve_objective(m[1])}"
      elsif m = instruct.match(/^([^\s]+)$/i)
        # > $objective
        resolve_objective(m[1])
      else
        raise "did not understand scoreboard instruction: `#{instruct}'"
      end
    end

    def resolve_scoreboard_op_instruct instruct
      if m = instruct.match(/^([^\s]+)\s+([^\s]+)\s+(=|\+=|\-=|\*=|\/=|%=|><|<|>)\s+([^\s]+)$/i)
        "scoreboard players operation #{m[2]} #{resolve_objective(m[1])} #{m[3]} #{m[4]} #{resolve_objective(m[1])}"
      elsif m = instruct.match(/^([^\s]+)\s+([^\s]+)\s+(=|\+=|\-=|\*=|\/=|%=|><|<|>)\s+([^\s]+)\s+([^\s]+)$/i)
        "scoreboard players operation #{m[2]} #{resolve_objective(m[1])} #{m[3]} #{m[5]} #{resolve_objective(m[4])}"
      else
        raise "did not understand scoreboard-operation instruction: `#{instruct}'"
      end
    end

    def resolve_fcall fcall
      fcall = "#{@context.function_namespace}:#{fcall}" unless fcall[T_NSSEP]

      if fcall["@"]
        fcall, fsched = fcall.split("@").map(&:strip)
        append = fsched.start_with?("<<")
        fsched = fsched[2..-1].strip if append
      end

      if fcall.start_with?("#{@context.function_namespace}:") && !(@context.functions[fcall.split(":")[1]] || @context.anonymous_functions[fcall.split(":")[1]])
        @warnings << "calling undefined function `#{fcall}' in #{@rsrc}:#{@li_no}"
      end

      if fsched
        $remid.scheduler.schedule(fcall, fsched, append: append)
      else
        "function #{fcall}"
      end
    end

    def result_buffer
      @result_buffer ||= parse
    end

    def as_string
      result_buffer.join("\n")
    end
  end
end
