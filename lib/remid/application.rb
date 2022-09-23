using Rainbow

module Remid
  class Application
    def self.dispatch *a
      new(*a) do |app|
        begin
          app.dispatch
        #rescue Interrupt
          #app.abort("Interrupted", 1)
        #rescue OptionParser::ParseError => ex
          #app.abort("#{ex.message}", false)
          #app.log app.c("Run `#{$0} --help' for more info", :blue)
          #exit 1
        #rescue StandardError => ex
          #app.warn app.c("[FATAL] #{ex.class}: #{ex.message}", :red)
          #ex.backtrace.each do |l|
          #  app.warn app.c("\t#{l}", :red)
          #end
          #app.abort case ex
          #  when Container::TableNotFoundError then ex.message
          #  else "Unhandled exception terminated application!"
          #end
        ensure
        end
      end
    end

    def initialize env, argv, &block
      @env = env
      @argv = argv
      @opts = { watch: false, copy: false, success_script: nil, failure_script: nil }
      parse_params
      yield(self)
    end

    def parse_params
      # -w --watch             autcompile on change
      # -c --copy <dst>        copy datapack to an additional directory/worldsave (omit pack-name)
      #                          e.g. --copy %appdata%\.minecraft\saves\THE_WORLD_SAVE\datapacks
      # -s --success <script>  run this cmd/ps1 script after successful compilation (and optional copy)
      # -f --failure <script>  run this cmd/ps1 script after failed compilation
    end

    def dispatch
      if @argv.length == 0
        puts "Usage: remid [options] <SRC_DIR>".cyan
        exit 1
      elsif !FileTest.directory?(@argv[0])
        puts "ERROR: Not a directory: #{@argv[0]}".red
      else
        catch :stop_parse_loop do
          loop do
            begin
              dst = SourceDirectory.new(@argv[0]).compile!

              if @opts[:copy]
                puts dst.inspect
                puts "@todo Copying not yet implemented"
              end

              if @opts[:success_script]
                puts "@todo Script invocation not yet implemented"
              end

              if @opts[:watch]
                puts "@todo Watching not yet implemented"
              else
                throw :stop_parse_loop, true
              end
            rescue StandardError => ex
              if @opts[:failure_script]
                puts "@todo Script invocation not yet implemented"
              end
              raise(ex) unless @opts[:watch]
            end
          end
        end
      end
    end
  end
end
