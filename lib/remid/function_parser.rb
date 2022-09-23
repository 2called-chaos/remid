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
    attr_reader :warnings, :payload, :context

    SPACES = [" ", "\t"].freeze
    ENCLOSERS = ["[", "]", "{", "}"].freeze
    T_SPACE = " ".freeze
    T_EVAL = "#~~".freeze
    T_EVAL_APPEND = "#~<".freeze
    T_BLOCK_OPEN = "#~[".freeze
    T_BLOCK_CLOSE = "#~]".freeze
    T_COMMENT = "#".freeze
    T_GT = ">".freeze
    T_GT_BANG = ">!".freeze
    T_GTEQ = ">=".freeze
    T_LT = "<".freeze
    T_LTEQ = "<=".freeze
    T_SLASH = "/".freeze
    T_NSSEP = ":".freeze

    def initialize context, payload, src, a_binding = nil, skip_indent: 0, li_offset: 0
      @context = context
      @payload = payload
      @a_binding = a_binding # || get_binding
      @src = @rsrc = src
      rt = @context.relative_target&.to_s
      if rt && @src.to_s.start_with?(rt)
        @rsrc = Pathname.new("." << @rsrc.to_s[rt.length..-1])
      end
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

    def parse
      raise "concurrent parse error" if Thread.current[:fparse_rbuf]
      cbuf = []
      [].tap do |rbuf|
        buf = payload.split("\n", -1)
        wbuf = warnings
        li_no = @li_offset
        state = {}
        state[:block_indent] = 0
        state[:prev_indent] = 0
        state[:indent] = 0
        state[:scoped_indent] = 0
        state[:block_buffer] = []
        state[:block_header] = nil
        state[:block_footer] = nil

        Thread.current[:fparse_rbuf] = rbuf
        Thread.current[:fparse_cbuf] = cbuf
        Thread.current[:fparse_wbuf] = wbuf
        while raw_line = buf.shift
          li_no += 1
          line = SeekableStringIO.new(raw_line)
          #puts "#{li_no}\t #{line.peek}"

          # skip indent (subs)
          (@skip_indent * @indent_per_level).times do
            line.readif(SPACES)
          end

          # indent
          cindent = line.read_while(SPACES)
          state[:prev_indent] = state[:indent]
          state[:indent] = cindent
          state[:indent_increased] = state[:prev_indent] < state[:indent]
          state[:indent_decreased] = state[:prev_indent] > state[:indent]
          state[:scoped_indent] += 1 if state[:indent_increased]
          state[:scoped_indent] -= 1 if state[:indent_decreased]

          peek1 = line.peek(1)

          if state[:block_indent] != 0
            if line.peek(T_BLOCK_OPEN.length) == T_BLOCK_OPEN
              state[:block_indent] += 1
              state[:block_buffer] << raw_line
              next
            elsif line.peek(T_BLOCK_CLOSE.length) == T_BLOCK_CLOSE && state[:block_indent] > 1
              state[:block_indent] -= 1
              state[:block_buffer] << raw_line
              next
            elsif !(line.peek(T_BLOCK_CLOSE.length) == T_BLOCK_CLOSE)
              state[:block_buffer] << raw_line
              next
            end
          end

          if line.peek.empty?
            # empty line
            cbuf << line.read
          elsif line.readif(T_EVAL_APPEND)
            line.read_while(SPACES) # padding
            eval_pos = line.pos
            to_eval = line.read
            begin
              cbuf << eval(to_eval, @a_binding).to_s
            rescue Exception => ex
              warn ">> in #{@src || "unknown"}:#{li_no}:#{eval_pos}"
              warn ">>   #{raw_line}"
              raise(ex)
            end
          elsif line.readif(T_EVAL)
            line.read_while(SPACES) # padding
            eval_pos = line.pos
            to_eval = line.read
            begin
              eval(to_eval, @a_binding)
            rescue Exception => ex
              warn ">> in #{@src || "unknown"}:#{li_no}:#{eval_pos}"
              warn ">>   #{raw_line}"
              raise(ex)
            end
          elsif line.readif(T_BLOCK_OPEN)
            line.read_while(SPACES) # padding
            # collect till end, evaluate and add to rbuf
            state[:block_indent] += 1
            #puts "open #{state[:block_indent]}"
            if state[:block_indent] == 1
              state[:block_header] = line.read
              rbuf << cbuf.shift while cbuf.length > 0
              #Thread.current[:fparse_cbuf] = cbuf = state[:block_buffer]
            end
          elsif line.readif(T_BLOCK_CLOSE)
            line.read_while(SPACES) # padding
            #puts "close #{state[:block_indent]}"
            # marks block end
            state[:block_indent] -= 1

            if state[:block_indent] == 0
              state[:block_footer] = line.read

              proc do
                a_binding = binding
                a_binding.local_variable_set(:a_context, @context)
                a_binding.local_variable_set(:a_src, @src)
                a_binding.local_variable_set(:a_buffer, state[:block_buffer].dup.freeze)
                a_binding.local_variable_set(:a_li_offset, li_no - state[:block_buffer].length - 1) # -1 because header
                a_binding.local_variable_set(:a_skip_indent, @skip_indent + 1)
                a_binding.local_variable_set(:x_binding, @a_binding)
                state[:block_buffer].clear

                to_eval = []
                to_eval <<  %{#{state.delete(:block_header)}}
                #to_eval << %q{  puts "li:#{a_skip_indent}"}
                #to_eval << %q{  puts "x:#{x rescue ??}"}
                #to_eval << %q{  puts "y:#{y rescue ??}"}
                to_eval << %q{  s_binding = binding}
                to_eval << %q{  if x_binding}
                to_eval << %q{    (x_binding.local_variables - s_binding.local_variables).each do |x|}
                to_eval << %q{      s_binding.local_variable_set(x, x_binding.local_variable_get(x))}
                to_eval << %q{    end}
                to_eval << %q{  end}
                to_eval << %q{  parent_thread = Thread.current}
                #to_eval << %q{  parent_thread = Thread.main unless parent_thread[:fparse_cbuf]}
                to_eval << %q{  thr = Thread.new do}
                to_eval << %q{    fp = FunctionParser.new(a_context, a_buffer.join("\n"), a_src, s_binding, skip_indent: a_skip_indent, li_offset: a_li_offset)}
                #to_eval << %q{    puts ">----------------------"}
                #to_eval << %q{    puts a_buffer.inspect}
                to_eval << %q{    puts "=---------------------"}
                to_eval << %q{    puts fp.result_buffer.inspect}
                to_eval << %q{    puts "<---------------------"}
                #to_eval << %q{    puts }
                #to_eval << %q{    puts }
                to_eval << %q{    puts parent_thread == Thread.main }
                to_eval << %q{    puts parent_thread[:fparse_cbuf].inspect }
                #to_eval << %q{    puts }
                to_eval << %q{    parent_thread[:fparse_cbuf] = parent_thread[:fparse_cbuf].concat fp.result_buffer.dup}
                #to_eval << %q{    puts parent_thread[:fparse_cbuf].inspect }
                to_eval << %q{    parent_thread[:fparse_wbuf] = parent_thread[:fparse_wbuf].concat fp.warnings}
                to_eval << %q{  end.join}
                to_eval <<  %{#{state.delete(:block_footer)}}
                #to_eval << %{rbuf << cbuf.shift while cbuf.length > 0}
                #to_eval << %{Thread.current[:fparse_cbuf] = cbuf = []}
                #puts nil, nil, to_eval, nil, nil
                # waitlock = Queue.new
                # thr = Thread.new do
                #   waitlock.pop
                #binding.pry
                  eval(to_eval.join("\n"), a_binding) #if @li_offset == 0
                # end
                #binding.pry
                #thr[:block_buffer] = state[:block_buffer].dup
                #thr[:skip_indent] = @skip_indent + 1
                # waitlock << true
                # thr.join

                #binding.pry

                #rbuf << cbuf.shift while cbuf.length > 0
                #rbuf << state[:block_buffer] while state[:block_buffer].length > 0
                #Thread.current[:fparse_cbuf] = cbuf = []
              end.call
            end
          elsif line.peek(1) == T_COMMENT
            if state[:indent] == state[:block_indent] * @indent_per_level
              cbuf << line.read
            else
              # inline comment, ignore
            end
          elsif line.readif(T_GT_BANG)
            # scoreboard operation helper
            line.read_while(SPACES) # padding

            instruct = process_interpolations(line.read)
            if m = instruct.match(/^([^\s]+) ([^\s]+) (=|\+=|\-=|\*=|\/=|%=|><|<) ([^\s]+)$/i)
              cbuf << "scoreboard players operation #{m[2]} #{m[1]} #{m[3]} #{m[4]} #{m[1]}"
            elsif m = instruct.match(/^([^\s]+) ([^\s]+) (=|\+=|\-=|\*=|\/=|%=|><|<) ([^\s]+) ([^\s]+)$/i)
              cbuf << "scoreboard players operation #{m[2]} #{m[1]} #{m[3]} #{m[5]} #{m[4]}"
            else
              raise "did not understand scoreboard-operation instruction: `#{instruct}'"
            end
          elsif line.readif(T_GT)
            # scoreboard helper
            line.read_while(SPACES) # padding

            instruct = process_interpolations(line.read)
            if m = instruct.match(/^([^\s]+) ([^\s]+) (=|\+=|\-=) (\d+)$/i)
              # > $objective $player = VAL
              # > $objective $player += VAL
              # > $objective $player -= VAL
              case m[3]
              when "="
                cbuf << "scoreboard players set #{m[2]} #{m[1]} #{m[4]}"
              when "+="
                cbuf << "scoreboard players add #{m[2]} #{m[1]} #{m[4]}"
              when "-="
                cbuf << "scoreboard players add #{m[2]} #{m[1]} #{m[4]}"
              end
            elsif m = instruct.match(/^([^\s]+) ([^\s]+) (reset|enable)$/i)
              # > $objective $player reset
              # > $objective $player enable
              cbuf << "scoreboard players #{m[3]} #{m[2]} #{m[1]}"
            elsif m = instruct.match(/^([^\s]+) ([^\s]+) (\+\+|\-\-)$/i)
              # > $objective $player ++
              # > $objective $player --
              case m[3]
              when "++"
                cbuf << "scoreboard players add #{m[2]} #{m[1]} 1"
              when "--"
                cbuf << "scoreboard players remove #{m[2]} #{m[1]} 1"
              end
            elsif m = instruct.match(/^([^\s]+) ([^\s]+)$/i)
              # > $objective $player
              cbuf << "scoreboard players get #{m[2]} #{m[1]}"
            else
              raise "did not understand scoreboard instruction: `#{instruct}'"
            end
          elsif line.readif(T_SLASH)
            # function helper
            fcall = process_interpolations(line.read)
            fcall = "#{@context.function_namespace}:#{fcall}" unless fcall[T_NSSEP]
            if fcall.start_with?("#{@context.function_namespace}:") && !@context.functions[fcall.split(":")[1]]
              wbuf << "calling undefined function `#{fcall}' in #{@rsrc}:#{li_no}"
            end
            cbuf << "function #{fcall}"
          else
            if !cbuf.last || state[:indent] == state[:block_indent] * @indent_per_level && !ENCLOSERS.include?(peek1)
              cbuf << process_interpolations(line.read)
            else
              cbuf.last << T_SPACE << process_interpolations(line.read)
            end
          end

          # @todo check for unreferenced functions
        end
        rbuf << cbuf.shift while cbuf.length > 0
        if Thread.current == Thread.main
          Thread.current[:fparse_rbuf] = nil
          Thread.current[:fparse_cbuf] = nil
        end
      end
    end

    def process_interpolations str
      # pointer = 0
      # while pointer < str.length

      # end
      # result =
      str#.gsub(/./, "!")
    end

    def result_buffer
      @result_buffer ||= parse
    end

    def as_string
      result_buffer.join("\n")
    end
  end
end
