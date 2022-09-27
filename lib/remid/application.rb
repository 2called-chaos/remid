using Rainbow

require "listen"

module Remid
  class Application
    def self.dispatch *a
      new(*a) do |app|
        begin
          app.parse_params
          app.dispatch
        rescue Interrupt
          warn "[ABORT] Interrupted"
          exit 2
        rescue OptionParser::ParseError => ex
          warn "[ABORT] #{ex.message}"
          warn "Run `#{$0} --help' for more info".cyan
          exit 1
        rescue Exception => ex
          warn "[FATAL] #{ex.class}: #{ex.message}".red
          ex.backtrace.each do |l|
           warn "\t#{l}".red
          end
          warn "Unhandled exception terminated application!".red
          exit 3
        ensure
        end
      end
    end

    def initialize env, argv, &block
      @env = env
      @argv = argv
      @opts = { watch: false, copy: false, success_script: nil, failure_script: nil }
      @monitor = Monitor.new
      @cond = @monitor.new_cond
      @pending = Queue.new
      init_params
      yield(self)
    end

    def init_params
      @optparse = OptionParser.new do |opts|
        opts.banner = "Usage: remid [options] <SRC_DIR>".cyan

        opts.separator("\n")
        opts.on("-h", "--help", String, "Shows this help") { puts @optparse.to_s; exit 1 }
        opts.on("-c", "--copy DST", String, "Copy datapack to a directory after compile", "e.g. into a world save") {|v| @opts[:copy] = v.to_s }
        opts.on("-s", "--success SCRIPT", String, "Run this script after successful compilations") {|v| @opts[:success_script] = v.to_s }
        opts.on("-f", "--failure SCRIPT", String, "Run this script after failed compilations") {|v| @opts[:failure_script] = v.to_s }
        opts.on("-w", "--watch", "Autocompile on changes in data source directory") { @opts[:watch] = true }
      end
    end

    def parse_params
      @optparse.parse!(@argv)
    end

    def indent_str str, indent = 2
      str.split("\n", -1).map{|s|
        "".rjust(indent) + s
      }.join("\n")
    end

    def dispatch
      if @argv.length == 0
        puts @optparse.to_s
        exit 1
      elsif !FileTest.directory?(@argv[0])
        puts "ERROR: Not a directory: #{@argv[0]}".red
      else
        @sd = SourceDirectory.new(@argv[0])
        if @opts[:watch]
          build_no = 0
          watch_source_directory
        end

        catch :stop_parse_loop do
          loop do
            begin
              build_no += 1 if @opts[:watch]
              dst = @sd.compile!(build_no: build_no)

              copy_build(dst, @opts[:copy]) if @opts[:copy]

              `#{@opts[:success_script]}` if @opts[:success_script]

              if @opts[:watch]
                wait_for_changes
              else
                throw :stop_parse_loop, true
              end
            #rescue FunctionParser::ParseError => ex
            rescue Exception => ex
              `#{@opts[:failure_script]}` if @opts[:failure_script]

              if @opts[:watch]
                warn indent_str("[FATAL] #{ex.class}: #{ex.message}".red, SourceDirectory::COL + 2)
                ex.backtrace.each do |l|
                  warn indent_str(l.red, SourceDirectory::COL + 4)
                end
                wait_for_changes
              else
                raise(ex)
              end
            end
          end
        end
      end
    end

    def copy_build build, target
      ctarget = Pathname.new(target)
      if target.end_with?("\\", "/")
        ctarget = ctarget.join(@sd.context.function_namespace)
      end

      puts @sd.col("COPY", :green) + "copying to #{ctarget.to_s.black.bright}"
      if !ctarget.dirname.directory?
        puts @sd.col("COPY", :red) + "missing parent directory #{ctarget.dirname}"
        ctarget.dirname.stat # raises when missing
        # when it's just not a directory
        raise "missing parent directory #{ctarget.dirname}"
      end

      if ctarget.exist? && !ctarget.join("pack.mcmeta").exist?
        puts @sd.col("COPY", :red) + "target exists but does not contain pack.mcmeta, for your data safety the directory has not been replaced: ".red + ctarget.to_s.magenta
        ctarget.join("pack.mcmeta").stat # raises when missing
        raise "target exists but does not contain pack.mcmeta" # to be sure
      end

      FileUtils.rm_r(ctarget) if ctarget.exist?
      FileUtils.cp_r(build, ctarget)
    end

    def wait_for_changes
      puts
      puts "".rjust(SourceDirectory::COL) + "  waiting for changes...".black.bright
      @pending.pop
      puts "".rjust(SourceDirectory::COL) + "  COMPILATION COMMENCING!".green.bright
      sleep 0.8
      system("cls")
    end

    def watch_source_directory
      return if @listener
      @listener = Listen.to(@sd.d_src, wait_for_delay: 1) do |modified, added, removed|
        @pending << @sd
        #puts(modified: modified, added: added, removed: removed)
      end
      #puts @sd.col("WATCHING", :magenta) + "#{@sd.d_src}".cyan
      @listener.start
    end
  end
end
