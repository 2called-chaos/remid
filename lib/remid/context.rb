module Remid
  class Context
    COL = 10
    attr_reader :opts, :meta, :objectives, :scheduler, :functions, :anonymous_functions, :blobs, :jsons, :parser, :on_load, :on_tick, :tag
    attr_accessor :function_namespace, :scoreboard_namespace, :relative_target

    def initialize
      @opts = OpenStruct.new({
        mcmeta: true,
        pretty_json: true,
        autofix_trailing_commas: false,
      })
      @functions = {}
      @anonymous_functions = {}
      @blobs = {}
      @jsons = {}
      @meta = OpenStruct.new(version: 10, description: "An undescribed datapack by an unknown author")
      @scheduler = FunctionScheduler.new(self)
      @objectives = ObjectiveManager.new(self)
      @tag = TagManager.new(self)
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

    def __remid_register_function fnc, payload, src = nil, **kw
      _fnc = fnc.to_s
      raise "duplicate function error #{_fnc}" if @functions[_fnc]
      raise "expected string, got #{payload.class}" unless payload.is_a?(String)
      @functions[_fnc] = FunctionParser.new(self, _fnc, payload, src, **kw)#.tap(&:result_buffer)
    end

    def __remid_register_anonymous_function fkey, payload
      with_fkey = @anonymous_functions.select {|_fnc, _| _fnc.start_with?("#{fkey}_") }
      same_with_fkey = with_fkey.detect {|_, _payload| payload == _payload }

      if same_with_fkey
        # reuse existing, identical anonymous function
        same_with_fkey[0]
      else
        "#{fkey}_#{with_fkey.length + 1}".tap do |fnc|
          @anonymous_functions[fnc] = payload
        end
      end
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

    def __remid_serialize &exporter
      data_path = Pathname.new("data")
      result = { count: 0, size: 0 }

      __remid_serialize_mcmeta(data_path, result, &exporter)
      __remid_serialize_remid_auto(data_path, result, :load, &exporter)
      __remid_serialize_remid_auto(data_path, result, :tick, &exporter)
      __remid_serialize_tags(data_path, result, &exporter)
      __remid_serialize_jsons(data_path, result, &exporter)
      __remid_serialize_functions(data_path, result, &exporter)
      __remid_serialize_anonymous_functions(data_path, result, &exporter)
      __remid_serialize_blobs(data_path, result, &exporter)

      result
    end

    def __remid_serialize_mcmeta data_path, result
      if @opts.mcmeta
        result[:count] += 1
        result[:size] += yield(:json, Pathname.new("pack.mcmeta"), { pack: @meta.to_h }, []).size
      end
    end

    def __remid_serialize_remid_auto data_path, result, fname
      fcol = instance_variable_get(:"@on_#{fname}")
      if fcol[0] == :__remid_auto
        fcol.shift
        fcol.unshift(fname.to_s) if @functions[fname.to_s]
      end

      if fcol.any?
        fwarns = []

        scoped_fcol = fcol.map do |lfunc|
          lfunc = "#{@function_namespace}:#{lfunc}" unless lfunc[FunctionParser::T_NSSEP]
          if lfunc.start_with?("#{@function_namespace}:") && !@functions[lfunc.split(":")[1]]
            fwarns << "calling undefined function `#{lfunc}' in $remid.on_#{fname}"
          end
          lfunc
        end

        result[:count] += 1
        result[:size] += yield(:json, data_path.join("minecraft/tags/functions/#{fname}.json"), { values: scoped_fcol }, fwarns).size
      end
    end

    def __remid_serialize_tags data_path, result
      @tag.tags.each do |_, tag_type|
        tag_type.tags.each do |_, tag|
          json_path = data_path.join("#{@function_namespace}/tags/#{tag_type.type}/#{tag.key}.json")
          result[:count] += 1
          result[:size] += yield(:json, json_path, tag.as_data, []).size
        end
      end
    end

    def __remid_serialize_jsons data_path, result
      @jsons.each do |rel_file, data|
        result[:fcount] += 1
        result[:size] += yield(:json, data_path.join(rel_file), data, []).size
      end
    end

    def __remid_serialize_functions data_path, result
      @functions.each do |rel_file, data|
        result[:count] += 1
        result[:size] += yield(:function, data_path.join(@function_namespace, "functions", Pathname.new("#{rel_file}.mcfunction")), data, data.warnings).size
      end
    end

    def __remid_serialize_anonymous_functions data_path, result
      @anonymous_functions.each do |rel_file, data|
        result[:count] += 1
        result[:size] += yield(:anonymous_function, data_path.join(@function_namespace, "functions", Pathname.new("#{rel_file}.mcfunction")), data, []).size
      end
    end

    def __remid_serialize_blobs data_path, result
      @blobs.each do |rel_file, file|
        result[:count] += 1
        result[:size] += yield(:blob, data_path.join(rel_file), file, []).size
      end
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