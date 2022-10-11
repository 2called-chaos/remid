module Remid
  class ResourcePack
    attr_reader :meta, :retextures, :sounds

    def initialize context, name, &block
      @name = name
      @context = context
      @merge_directories = []
      @sound_directories = []
      @retextures = {}
      @meta = { pack: { pack_format: 9, description: @name } }
      setup(&block) if block
    end

    def setup
      yield(self) if block_given?
      self
    end

    def merge_directory dir
      @merge_directories << @context.relative_target.join(dir)
    end

    def include_sound_directory dir
      @sound_directories << @context.relative_target.join(dir)
    end

    def link_as target
      @link_as = @context.relative_target.join(target)
    end

    def copy_to target
      @copy_to = @context.relative_target.join(target)
    end

    def simple_retexture item, **kw, &block
      @retextures[item] = BasicRetexture.new(item, **kw).setup(&block)
    end

    def _write_json file, data
      FileUtils.mkdir_p(File.dirname(file))
      File.open(file, "wb") do |f|
        f.write($remid.opts.pretty_json ? JSON.pretty_generate(data) : JSON.generate(data))
      end
    end

    def build_to dir
      target_base = @context.relative_target.join(dir)
      base = Pathname.new("#{target_base}.build")

      _build_mcmeta(base)
      _build_merge_directories(base)
      _build_include_sounds(base)
      _build_retextures(base)

      FileUtils.rm_rf(target_base.to_s)
      FileUtils.mv(base, target_base)

      if @link_as
        ltarget = Pathname.new(@link_as)
        if ltarget.exist? && ltarget.symlink?
          current_link = ltarget.readlink
          if current_link != target_base.realpath
            raise "link target exists but links to wrong destination, expected `#{target_base}', got `#{current_link}'!"
          end
        elsif ltarget.exist?
          raise "target exists but is not a symlink #{ltarget.stat.inspect}"
        elsif ltarget.dirname.directory?
          begin
            FileUtils.ln_s(target_base, ltarget)
          rescue Errno::EACCES => ex
            if Gem.win_platform?
              raise "On Windows we can only symlink if you run remid elevated (right click -> run as administrator)\n(#{ex})"
            end
            raise
          end
        else
          raise "link target parent directory does not exist: #{ltarget.dirname}"
        end
      end

      if @copy_to
        ctarget = Pathname.new(@copy_to)
        if ctarget.to_s.end_with?("\\", "/")
          ctarget = ctarget.join(@context.function_namespace)
        end

        if !ctarget.dirname.directory?
          warn "missing parent directory #{ctarget.dirname}"
          ctarget.dirname.stat # raises when missing
          # when it's just not a directory
          raise "missing parent directory #{ctarget.dirname}"
        end

        if ctarget.exist? && !ctarget.join("pack.mcmeta").exist?
          warn "target exists but does not contain pack.mcmeta, for your data safety the directory has not been replaced: ".red + ctarget.to_s.magenta
          ctarget.join("pack.mcmeta").stat # raises when missing
          raise "target exists but does not contain pack.mcmeta" # to be sure
        end

        FileUtils.rm_r(ctarget) if ctarget.exist?
        FileUtils.cp_r(target_base, ctarget)
      end

      target_base
    ensure
      FileUtils.rm_rf(base.to_s) if base.exist?
    end

    def _build_mcmeta base
      _write_json(base.join("pack.mcmeta"), @meta)
    end

    def _build_merge_directories base
      @merge_directories.each do |md|
        Find.find(md.to_s) do |path|
          if FileTest.directory?(path)
            if File.basename(path).start_with?(".")
              puts "prune #{path.inspect}"
              Find.prune
            end
          else
            file = Pathname.new(path)
            target = base.join(file.relative_path_from(md))
            FileUtils.mkdir_p(target.dirname)
            FileUtils.cp(file, target)
          end
        end
      end
    end

    def _build_include_sounds base
      sound_json_file = base.join("assets", @context.function_namespace, "sounds.json")
      if sound_json_file.exist?
        sound_json = JSON.parse(sound_json_file)
      else
        sound_json = {}
      end

      @sound_directories.each do |sd|
        Find.find(sd.to_s) do |path|
          if FileTest.directory?(path)
            if File.basename(path).start_with?(".")
              puts "prune #{path.inspect}"
              Find.prune
            end
          else
            file = Pathname.new(path)
            relpath = file.relative_path_from(sd)
            target = base.join("assets", @context.function_namespace, "sounds", relpath)
            FileUtils.mkdir_p(target.dirname)
            FileUtils.cp(file, target)
            key = "#{relpath.dirname}/#{relpath.basename(".ogg")}"
            sound_json[key.gsub("/", ".")] = { sounds: ["#{@context.function_namespace}:#{key}"] }
          end
        end
      end

      _write_json(sound_json_file, sound_json)
    end

    def _build_retextures base
      @retextures.each do |item, retext|
        retext.serialize_to(base) do |file, data|
          _write_json(file, data)
        end
      end
    end

    class BasicRetexture
      def initialize(item, **kw)
        @item = item
        @retexture_as = kw[:as] || "item/handheld"
        @offset = kw[:offset] || 1
        @variants = {}
      end

      def setup
        yield(self) if block_given?
        self
      end

      def variant vh
        k, v = vh.to_a.first
        @variants[k] = v
        self
      end

      def serialize_to base
        item_base = base.join("assets", "minecraft", "models", @item)
        FileUtils.mkdir_p(item_base)
        item_json = { parent: @retexture_as, textures: { layer0: @item }, overrides: [] }
        @variants.each_with_index do |(name, parent), i|
          yield(item_base.join("#{name}.json"), { parent: parent })
          item_json[:overrides] << { predicate: { custom_model_data: @offset + i }, model: "#{@item}/#{name}"}
        end
        yield("#{item_base}.json", item_json)
      end

      def to_index_hash
        {}.tap do |r|
          @variants.each_with_index do |(k, v), i|
            r[k] = @offset + i
          end
        end
      end
    end
  end
end
