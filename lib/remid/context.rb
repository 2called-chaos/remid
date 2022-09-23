module Remid
  class Context
    COL = 10
    attr_reader :opts, :meta, :objectives, :scheduler, :functions, :blobs, :jsons, :parser, :on_load, :on_tick
    attr_accessor :function_namespace, :scoreboard_namespace, :relative_target

    def initialize
      @opts = OpenStruct.new({
        mcmeta: true,
        pretty_json: true,
      })
      @functions = {}
      @blobs = {}
      @jsons = {}
      @meta = OpenStruct.new(version: 10, description: "An undescribed datapack by an unknown author")
      @scheduler = FunctionScheduler.new(self)
      @objectives = ObjectiveManager.new(self)
      @on_load = [:__remid_auto]
      @on_tick = [:__remid_auto]
    end

    def on_load= value
      if value
        if value.is_a?(Array)
          @on_load = value
        else
          @on_load = [value]
        end
      else
        @on_load = []
      end
    end

    def on_tick= value
      if value
        if value.is_a?(Array)
          @on_tick = value
        else
          @on_tick = [value]
        end
      else
        @on_tick = []
      end
    end

    def __remid_load_manifest file
      eval file.read, binding, file.to_s
      @scheduler.namespace || raise("remid.rb must define a function_namespace")
      @objectives.namespace || raise("remid.rb must define a scoreboard_namespace")
    end

    def __remid_register_function fnc, payload, src = nil
      _fnc = fnc.to_s
      raise "duplicate function error #{_fnc}" if @functions[_fnc]
      raise "expected string, got #{payload.class}" unless payload.is_a?(String)
      @functions[_fnc] = FunctionParser.new(self, payload, src)
    end

    def get_binding
      binding
    end

    def __remid_register_blob file, rel_file
      raise "duplicate blob error #{rel_file}" if @blobs[rel_file]
      @blobs[rel_file] = file
    end

    def __remid_register_json rel_file, data
      raise "duplicate json error #{rel_file}" if @jsons[rel_file]
      @jsons[rel_file] = data
    end

    def __remid_serialize
      fcount, size = 0, 0
      data_path = Pathname.new("data")

      if @opts.mcmeta
        fcount += 1
        size += yield(:json, Pathname.new("pack.mcmeta"), { pack: @meta.to_h }, []).size
      end

      if @on_load[0] == :__remid_auto
        @on_load.shift
        @on_load.unshift("load") if @functions["load"]
      end
      if @on_load.any?
        fwarns = []

        scoped_on_load = @on_load.map do |lfunc|
          lfunc = "#{@function_namespace}:#{lfunc}" unless lfunc[FunctionParser::T_NSSEP]
          if lfunc.start_with?("#{@function_namespace}:") && !@functions[lfunc.split(":")[1]]
            fwarns << "calling undefined function `#{lfunc}' in $remid.on_load"
          end
          lfunc
        end

        fcount += 1
        size += yield(:json, Pathname.new("data/minecraft/tags/functions/load.json"), { values: scoped_on_load }, fwarns).size
      end

      if @on_tick[0] == :__remid_auto
        @on_tick.shift
        @on_tick.unshift("tick") if @functions["tick"]
      end
      if @on_tick.any?
        fwarns = []

        scoped_on_tick = @on_tick.map do |lfunc|
          lfunc = "#{@function_namespace}:#{lfunc}" unless lfunc[FunctionParser::T_NSSEP]
          if lfunc.start_with?("#{@function_namespace}:") && !@functions[lfunc.split(":")[1]]
            fwarns << "calling undefined function `#{lfunc}' in $remid.on_tick"
          end
          lfunc
        end

        fcount += 1
        size += yield(:json, Pathname.new("data/minecraft/tags/functions/tick.json"), { values: scoped_on_tick }, fwarns).size
      end

      @jsons.each do |rel_file, data|
        fcount += 1
        size += yield(:json, data_path.join(rel_file), data, []).size
      end

      @functions.each do |rel_file, data|
        fcount += 1
        size += yield(:function, data_path.join(@function_namespace, "functions", Pathname.new("#{rel_file}.mcfunction")), data, data.warnings).size
      end

      @blobs.each do |rel_file, file|
        fcount += 1
        size += yield(:blob, data_path.join(rel_file), file, []).size
      end
      [fcount, size]
    end

    def function_namespace= value
      @function_namespace = value.presence
      @scheduler.namespace = @function_namespace
      self.scoreboard_namespace = value unless @scoreboard_namespace
    end

    def scoreboard_namespace= value
      @scoreboard_namespace = value.presence
      @objectives.namespace = @scoreboard_namespace
    end



    # ------------------
    # --- Public API ---
    # ------------------

    def stub func, to_exec = nil, &execute
      if execute
        r = []
        execute.call(r)
        __remid_register_function(func, r.join("\n"), "#{caller.first}<STUBBED #{func}>")
      elsif to_exec.is_a?(Array)
        __remid_register_function(func, to_exec.map{|fnc| "/#{fnc}" }.join("\n"), "#{caller.first}<STUBBED #{func}>")
      elsif to_exec.is_a?(String)
        lines = to_exec.split("\n", -1)
        lines.shift if lines.first == ""
        flio = SeekableStringIO.new(lines.detect(&:presence))
        indent = ""
        while x = flio.readif(FunctionParser::SPACES)
          indent << x
        end
        fixed_exec = lines.map{|l| l[indent.length..-1] }.join("\n")
        __remid_register_function(func, fixed_exec, "#{caller.first}<STUBBED #{func}>")
      else
        raise ArgumentError, "unknown execution type #{to_exec.class}"
      end
    end

    def capture &block
      proc do |*args|
        #Thread.new do
          block.call(*args)
        #end.join
      end
    end
  end
end
