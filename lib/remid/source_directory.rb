using Rainbow

module Remid
  class SourceDirectory
    COL = 10
    attr_reader :dir, :d_src, :d_bld, :d_dst, :context

    def initialize dir
      @dir = Pathname.new(dir.delete_suffix("/").delete_suffix("\\"))
      @src = "data"
      @dst = "_datapack"
      @d_src = @dir.join(@src)
      @d_bld = @dir.join(".build")
      @d_dst = @dir.join(@dst)
      @d_dstp = @dir.join("#{@dst}.prev")

      $remid = @context = Context.new(self)
      @context.relative_target = @dir
      @context.__remid_load_manifest(@dir.join("remid.rb"))
    end

    def col name = "", color = :black
      name.rjust(COL).color(color) + "  "
    end

    def compile! build_no: nil
      puts col("COMPILING", :yellow) + @dir.to_s.magenta
      $remid = @context = Context.new(self)
      @context.relative_target = @dir
      @context.__remid_load_manifest(@dir.join("remid.rb"))
      return unless ensure_source

      result = nil
      rt = Benchmark.realtime {
        create_build_directoy
        collect_source_files(@context)
        puts col("WRITING", :yellow) + "writing pack data"
        result = serialize_context(@context)
      }
      result[:rt] = rt
      finally_move_build(result, build_no: build_no)
    end

    def ensure_source
      if !@d_src.exist?
        warn col("ERROR", :red) + "the target directory is missing the data folder './#{@src}'".red
        return
      end

      if !@dir.join("remid.rb").exist?
        warn col("ERROR", :red) + "the target directory is missing a remid file './remid.rb'".red
        return
      end
      return true
    end

    def create_build_directoy
      # clear & create build directory
      if @d_bld.exist?
        puts col("INFO", :cyan) + " clearing old build ".cyan + "./.build".blue
        FileUtils.rm_rf(@d_bld)
      end
      FileUtils.mkdir_p(@d_bld)
    end

    def collect_source_files context
      # collect files
      Find.find(@d_src) do |path|
        if FileTest.directory?(path)
          if File.basename(path).start_with?(".")
            puts "prune #{path.inspect}"
            Find.prune
          end
        else
          file = Pathname.new(path)
          rel_file = file.relative_path_from(@d_src)

          if rel_file.parent.fnmatch(".")
            rel_file = rel_file.parent.parent.join(rel_file)
          end

          case file.extname
          when ".json" # validate json is readable
            begin
              context.__remid_register_json(rel_file, JSON.parse(file.read))
            rescue StandardError => ex
              warn col("ERROR", :red) + "./" + rel_file.to_s
              warn col + "#{ex.class}: #{ex.message}"
              #raise ex
              exit 1
            end
          when ".mcfunction" # compile
            begin
              funcname = rel_file.relative_path_from("#{context.function_namespace}/functions").to_s.delete_suffix(".mcfunction")
              context.__remid_register_function(funcname, file.read, file.to_s)
            rescue StandardError => ex
              warn col("ERROR", :red) + "./" + rel_file.to_s
              warn col + "#{ex.class}: #{ex.message}"
              #raise ex
              exit 1
            end
          else # just copy
            context.__remid_register_blob(file, rel_file)
          end
        end
      end
    end

    def serialize_context ctx
      ctx.__remid_serialize do |type, rel_file, file_or_data, warnings|
        FileUtils.mkdir_p(@d_bld.join(rel_file.dirname))
        case type
        when :blob
          already_exists = File.exist?(@d_bld.join(rel_file))
          puts col("F", already_exists ? :red : :magenta) + "./" + rel_file.to_s
          if already_exists
            warn col("") + "  ! ".red + "overwriting existing (generated) file".red
          end
          FileUtils.cp(file_or_data, @d_bld.join(rel_file))
        when :json
          puts col("*", :silver) + "./" + rel_file.to_s
          print_serialization_warnings(warnings)
          File.open(@d_bld.join(rel_file), "wb") {|f| f.write(ctx.opts.pretty_json ? JSON.pretty_generate(file_or_data) : JSON.generate(file_or_data)) }
        when :function
          if file_or_data.exception
            puts col("ERROR #", :red) + "./" + rel_file.to_s
            raise(file_or_data.exception)
          end
          puts col(warnings.empty? ? "#" : "WARN #", warnings.empty? ? :green : :yellow) + "./" + rel_file.to_s
          print_serialization_warnings(warnings)
          File.open(@d_bld.join(rel_file), "wb") {|f| f.write(file_or_data.as_string) }
        when :anonymous_function
          puts col("#", :green) + "./" + rel_file.to_s
          File.open(@d_bld.join(rel_file), "wb") {|f| f.write(file_or_data) }
        else
          raise "don't know how to serialize #{type}"
        end
        @d_bld.join(rel_file)
      end
    end

    def print_serialization_warnings warnings
      warnings.each do |warning|
        if warning.start_with?("autofix: ")
          warn col("") + "  i ".yellow + warning[9..-1].cyan
        else
          warn col("") + "  ! ".red + warning.red
        end
      end
    end

    def finally_move_build result, build_no: nil
      # move old build if it exists
      if @d_dst.exist?
        puts col("INFO", :cyan) + "moving " + "./#{@dst}".cyan + " to " + "./#{@dst}.prev".blue
        FileUtils.rm_rf(@d_dstp) if @d_dstp.exist?
        FileUtils.mv(@d_dst, @d_dstp)
      end

      # move finished build
      fsize = result[:size] > 1024 * 1024 ? "#{"%.2f" % (result[:size].to_f / (1024 * 1024))}MB" : "#{"%.2f" % (result[:size].to_f / (1024))}KB"
      puts col("SUCCESS", :green) + "Build#{"[##{build_no}]" if build_no} successfully to ".white + "./#{@dst}".cyan + " in ".white + "#{"%.3f" % result[:rt]}s".yellow
      puts col("INFO", :cyan)     + "#{result[:count]}".yellow + " files / " + fsize.yellow
      FileUtils.mv(@d_bld, @d_dst)
      @d_dst
    end
  end
end
__END__

# ------------
# --- Meta ---
# ------------

$remid.description          = "Mystery Castle by 2called-chaos"
$remid.function_namespace   = "mystery_castle"
$remid.scoreboard_namespace = "mc"
# "imports" or easier access
$scores = $remid.objectives
$schedule = $remid.scheduler



# ------------------
# --- Objectives ---
# ------------------

$scores.add :registry
$scores.add :sneak, "minecraft.custom:minecraft.sneak_time"



# -----------------
# --- Variables ---
# -----------------

$center = Coord.new(123, 123, 123) # ground level center point of the tower
$height = 30 # how high can we go from center point
$depth  = 30 # how low can we go from center point
$long_axis = :z # which axis is the long one (tower isn't square)



# -------------------------
# --- Stubbed functions ---
# -------------------------

$remid.stub :load, %q{
  #~~ $remid.objectives.registry.create
  execute unless score $z_initialized #{$score.registry} matches 1 run #{/init}
  execute unless score $z_installed #{$score.registry} matches 1 run #{/install}
  say MysteryCastle ready
}

# ChaosCore Post - makes sure CCpost runs after us
# (disable in development or reloading will be annoying as fuck)
$remid.stub :install, %q{
  #/chaos_core:install
  > registry $z_installed = 1
}

# Kill all entities and remove all objectives
$remid.stub :kill, %q{
  say Deconstructing MysteryCastle
  #~~ $remid.objectives.destroy_all
  kill @e[tag=mystery_castle]
}

$remid.stub :reload, [:kill, :init]
