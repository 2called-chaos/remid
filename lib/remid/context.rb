module Remid
  class Context
    COL = 10
    attr_reader :opts, :sd, :scope, :vectors, :meta, :objectives, :scheduler, :advancements, :strings, :functions, :anonymous_functions, :blobs, :jsons, :parser, :on_load, :on_tick, :tag, :knows_world_spawn
    attr_accessor :function_dir, :function_namespace, :scoreboard_namespace, :relative_target, :teams

    def initialize sd, global_vars = nil, scope: :compile
      @scope = scope
      @global_vars = global_vars || global_variables
      @sd = sd
      @opts = OpenStruct.new({
        mcmeta: true,
        pretty_json: true,
        autofix_trailing_commas: false,
        function_book: true,
      })
      @uuid = 0
      @post_serializers = []
      @functions = {}
      @anonymous_functions = {}
      @blobs = {}
      @jsons = {}
      @watch = []
      @meta = OpenStruct.new(pack_format: 10, description: "An undescribed datapack by an unknown author")
      @scheduler = FunctionScheduler.new(self)
      @objectives = ObjectiveManager.new(self)
      @advancements = AdvancementManager.new(self)
      @strings = StringCollection.new(self)
      @teams = TeamManager.new(self)
      @tag = TagManager.new(self)
      @on_load = [:__remid_auto]
      @on_tick = [:__remid_auto]

      @vectors = OpenStruct.new(Coord::VECTORS)
      @vectors.rotation = {
        north: AngleGroup.new(-180.0, 0.0).deep_freeze,
        east:  AngleGroup.new(-90.0, 0.0).deep_freeze,
        south: AngleGroup.new(0.0, 0.0).deep_freeze,
        west:  AngleGroup.new(90.0, 0.0).deep_freeze,
      }.freeze
    end

    def post_serialize &block
      @post_serializers << block
    end

    def deregister!
      (global_variables - @global_vars).each do |var|
        eval("#{var} = nil")
      end
    end

    def uuid
      @uuid += 1
      @uuid
    end

    def buf cbuf = nil
      cbuf ||= Thread.current[:fparse_cbuf]
      raise "no context" unless cbuf
      cbuf
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

    def remember_world_spawn
      buf << "kill @e[tag=__remid.world_spawn]"
      buf << "summon marker ~ ~ ~ {Tags:[__remid.world_spawn]}"
      @knows_world_spawn = true
    end

    def knows_world_spawn?
      !!@knows_world_spawn
    end

    def watch *paths
      paths.each do |path|
        if path.is_a?(String) && path.start_with?("./")
          @watch << @sd.dir.join(path)
        else
          @watch << path
        end
      end
      @watch
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
      same_with_fkey = with_fkey.detect {|_, _payload| payload.result_buffer == _payload.result_buffer }

      if same_with_fkey
        # reuse existing, identical anonymous function
        same_with_fkey[0]
      else
        "#{fkey}_#{with_fkey.length + 1}".tap do |fnc|
          @anonymous_functions[fnc] = payload
        end
      end
    end

    def __remid_register_unique_anonymous_function fkey
      with_fkey = @anonymous_functions.select {|_fnc, _| _fnc.start_with?("#{fkey}_") }
      "#{fkey}_#{with_fkey.length + 1}".tap do |fnc|
        @anonymous_functions[fnc] = yield(fnc)
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
      result = { count: 0, size: 0, warnings: 0 }

      if @opts[:function_book]
        @functions["__remid/fnbook"] = Remid::FunctionBook.new(self)
      end

      __remid_serialize_mcmeta(data_path, result, &exporter)
      __remid_serialize_remid_auto(data_path, result, :load, &exporter)
      __remid_serialize_remid_auto(data_path, result, :tick, &exporter)
      __remid_serialize_tags(data_path, result, &exporter)
      __remid_serialize_jsons(data_path, result, &exporter)
      __remid_serialize_functions(data_path, result, &exporter)
      __remid_serialize_anonymous_functions(data_path, result, &exporter)
      __remid_serialize_advancements(data_path, result, &exporter)
      __remid_serialize_blobs(data_path, result, &exporter)

      @post_serializers.each do |serializer|
        serializer.call(result, self)
      end

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

        result[:warnings] += fwarns.length
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
      pfn = Pathname.new(@function_namespace)
      @jsons.each do |rel_file, data|
        result[:count] += 1
        scoped_path = pfn.join(rel_file.relative_path_from(@function_dir))
        result[:size] += yield(:json, data_path.join(scoped_path), data, []).size
      end
    end

    def __remid_recurse_process fnlist
      processed = []
      i = 0
      while (fnlist.keys - processed).any?
        fnlist.dup.each do |rel_file, data|
          next if processed.include?(rel_file)
          processed << rel_file
          begin
            data.result_buffer # pre-parse for warnings and exceptions
          rescue Exception => ex
            data.exception = ex
          end
        end

        i += 1
        if i > 100
          raise "RecursionError: kept resolving to new functions after 100 iterations, aborting..."
        end
      end
    end

    def __remid_serialize_functions data_path, result
      __remid_recurse_process(@functions)

      @functions.each do |rel_file, data|
        data.finalize_buffer!
        result[:warnings] += data.warnings.length
        result[:count] += 1
        result[:size] += yield(:function, data_path.join(@function_namespace, "functions", Pathname.new("#{rel_file}.mcfunction")), data, data.warnings).size
      end
    end

    def __remid_serialize_anonymous_functions data_path, result
      __remid_recurse_process(@anonymous_functions)

      @anonymous_functions.each do |rel_file, data|
        data.finalize_buffer!
        result[:warnings] += data.warnings.length
        result[:count] += 1
        result[:size] += yield(:anonymous_function, data_path.join(@function_namespace, "functions", Pathname.new("#{rel_file}.mcfunction")), data, data.warnings).size
      end
    end

    def __remid_serialize_advancements data_path, result
      @advancements.each do |key, adv|
        res = adv.to_result
        result[:warnings] += res[:warnings].length
        result[:count] += 1
        result[:size] += yield(:advancement, data_path.join(@function_namespace, "advancements", Pathname.new("#{adv.scoped_key}.json")), res[:data], res[:warnings]).size
      end
    end

    def __remid_serialize_blobs data_path, result
      pfn = Pathname.new(@function_namespace)
      @blobs.each do |rel_file, file|
        result[:count] += 1
        scoped_path = pfn.join(rel_file.relative_path_from(@function_dir))
        result[:size] += yield(:blob, data_path.join(scoped_path), file, []).size
      end
    end

    def function_namespace= value
      @function_namespace = value.presence
      @scheduler.namespace = @function_namespace
      self.scoreboard_namespace = value unless @scoreboard_namespace
      self.function_dir = value unless @function_dir
    end

    def scoreboard_namespace= value
      @scoreboard_namespace = value.presence
      @objectives.namespace = @scoreboard_namespace
    end

    def __deindent_by_first_line str
      lines = str.split("\n", -1)
      lines.shift if lines.first == ""
      indent = ""
      if fl = lines.detect(&:presence)
        flio = SeekableStringIO.new(fl)
        while x = flio.readif(FunctionParser::SPACES)
          indent << x
        end
      end
      lines.map{|l| l[indent.length..-1] }.join("\n")
    end

    def j str = nil
      JsonHelper::PresentedMinecraftString.wrap(str || "")
    end

    def __stub_invsave_functions
      @objectives.add :__remid_invsave unless @objectives.__remid_invsave?

      stub_nil("__remid/invsave/save_failure", %{
        tellraw @s \#{j("Failed to store your inventory!").red}
        tellraw @s \#{j("(you probably already have an active save)").red}
      })

      _tmpmarker = "type=marker,tag=__remid.invsave.player_inventory,tag=__remid.pending"
      stub_nil("__remid/invsave/save", %{
        # summon marker
        summon marker ~ ~ ~ { Tags: [__remid, __remid.invsave, __remid.invsave.player_inventory, __remid.pending] }

        # link marker to player
        >! /cc_id @e[#{_tmpmarker}] = @s

        # copy inventory
        data modify entity @e[#{_tmpmarker},limit=1] data.Inventory set from entity @s Inventory

        # teleport marker to spawn if possible
        execute if entity @e[type=marker,tag=__remid.world_spawn] run
          tp @e[#{_tmpmarker}] @e[type=marker,tag=__remid.world_spawn,limit=1]

        # marker is finalised
        tag @e[#{_tmpmarker},limit=1] remove __remid.pending

        # tag player as having an inventory saved
        tag @s add __remid.invsave.saved
      })

      stub_nil("__remid/invsave/restore_failure", %{
        tellraw @s #{j("Failed to restore your inventory!").red}
        tellraw @s \#{j("(you probably have no save or the marker got unloaded)").red}
      })

      stub_nil("__remid/invsave/restore", %{
        # tag player
        tag @s add __remid.invsave.is_restoring

        # find marker and restore it
        execute
          at @s
          as @e[type=marker,tag=__remid.invsave.player_inventory,tag=!__remid.pending]
          if score @s cc_id = @a[tag=__remid.invsave.is_restoring,limit=1] cc_id
          run \#{/./restore_marker}

        # remove tag from player
        tag @s remove __remid.invsave.is_restoring
        tag @s remove __remid.invsave.saved
      })

      _holdent = "type=armor_stand,tag=__remid.invsave.restore_holdent"
      stub_nil("__remid/invsave/restore_marker", %{
        # summon temporary inventory holding entity
        summon armor_stand ~ ~ ~ { Tags: [__remid, __remid.invsave, __remid.invsave.restore_holdent] }

        # tag marker to find it again in sub
        tag @s add __remid.invsave.is_restoring_from

        # give items back
        execute if data entity @s data.Inventory[0] run \#{/./return_marker_items_recurse}

        # kill temp holder & marker
        kill @e[type=armor_stand,tag=__remid.invsave.restore_holdent]
        kill @s
      })

      stub_nil("__remid/invsave/return_marker_items_recurse", %{
        # remember slot number
        execute store result score #rslot \#{> __remid_invsave} run data get entity @s data.Inventory[0].Slot

        # remove the slot data so it doesn't get removed from the chest
        data remove entity @s data.Inventory[0].Slot

        # copy the item data to the holder entity
        data modify entity @e[#{_holdent},limit=1] HandItems[0] set from entity @s data.Inventory[0]

        # give player the item based the slot number
        execute as @a[tag=__remid.invsave.is_restoring] run \#{/./return_item_to_correct_slot}

        # remove item data from entity
        data remove entity @s data.Inventory[0]

        # recurse
        execute if data entity @s data.Inventory[0] run \#{/::self}
      })

      _csinvsel = "type=armor_stand,tag=__remid.invsave.restore_holdent,limit=1"
      stub_nil("__remid/invsave/return_item_to_correct_slot") do |aout|
        restore_slot = proc do |rslot, outslot|
          aout << "execute if score #rslot \#{> __remid_invsave} matches #{rslot} run"
          aout << "\titem replace entity @s #{outslot} from entity @e[#{_holdent},limit=1] weapon.mainhand"
        end

        restore_slot[-106, "weapon.offhand"]
        9.times {|i| restore_slot[i, "hotbar.#{i}"] }
        restore_slot[100, "armor.feet"]
        restore_slot[101, "armor.legs"]
        restore_slot[102, "armor.chest"]
        restore_slot[103, "armor.head"]
        27.times {|i| restore_slot[9 + i, "inventory.#{i}"] }
      end
    end



    # ------------------
    # --- Public API ---
    # ------------------

    def stub_nil func, to_exec = nil, &execute
      return @functions[func] if @functions[func]
      stub(func, to_exec, &execute)
    end

    def stub func, to_exec = nil, &execute
      if execute
        r = []
        execute.call(r)
        __remid_register_function(func, r.join("\n"), "#{caller.first}<STUBBED #{func}>")
      elsif to_exec.is_a?(Array)
        __remid_register_function(func, to_exec.map{|fnc| "/#{fnc}" }.join("\n"), "#{caller.first}<STUBBED #{func}>")
      elsif to_exec.is_a?(String)
        __remid_register_function(func, __deindent_by_first_line(to_exec), "#{caller.first}<STUBBED #{func}>")
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

    def resource_pack name, &block
      ResourcePack.new(self, name, &block)
    end

    def import_sounds_from_pack base, namespace = nil
      Sound.group_from_json(relative_target.join(base, "assets", namespace || @function_namespace, "sounds.json"), namespace || @function_namespace)
    end
  end
end
