module Remid
  class JsonStorageContext
    def initialize storage, *args, name: "jsontext", mode: :normal, &block
      @storage, @name = storage, name
      @mode = mode
      @args = args
      @buffer = []
      build(&block) if block
    end

    def build &block
      yield(self, *@args)
    end

    def << str
      buf = str
      # buf = buf.call if buf.is_a?(Proc)
      buf = buf.to_s.gsub("\\u", "\\\\\\u").gsub("'", "\\\\'")

      if @mode == :append
        %{data modify storage #{@storage} #{@name} append value '[#{buf}]'}
      else
        @mode = :append
        %{data modify storage #{@storage} #{@name} set value ['[#{buf}]']}
      end
    end

    def to_s
      "?"
    end

    def tell target = "@s"
      %{tellraw #{target} [{"nbt":"#{@name}[]","storage":"#{@storage}","interpret":true,"separator":""}]}
    end

    def concat src_storage, name = "jsontext"
      unless $remid
        raise "cannot concat json storages without remid context"
      end
      unless Thread.current[:fparse_inst]
        raise "cannot concat json storages without function parser context"
      end

      # $whatthefuckisgoingon = true
      Thread.current[:fparse_inst].resolve_fcall Thread.current[:fparse_inst].anonymous_function{|aout|
        aout << "execute as @s[tag=__remid.invsave.saved] run failure"
        aout << "execute as @s[tag=!__remid.invsave.saved] run <<<"
        aout << "\tsave"
        aout << "\texecute as @s[tag=!__remid.invsave.saved] run <<<"
        aout << "\t\tsave"
        aout << "\t>>>"
        aout << ">>>"
      }
      $whatthefuckisgoingon = false
      # Thread.current[:fparse_inst].resolve_fcall Thread.current[:fparse_inst]._execute_sub([].tap{|aout|
      #   aout << "\tdata modify storage #{src_storage} p_merge set value 0"
      #   aout << "\texecute runa <<<"
      #   aout << "\t\texecute runb <<<"
      #   aout << "\t\t\texecute runc <<<"
      #   # aout << "  $execute"
      #   # aout << "    if data storage #{src_storage} jsontext[$(p_merge)]"
      #   # aout << "    run xxx<<~"
      #   # aout << "      $data modify storage #{@storage} jsontext append from storage #{src_storage} jsontext[$(p_merge)]"
      #   # aout << ""
      #   # aout << "      # increase pointer"
      #   # aout << "      execute store result score p_jsontext \#{> registry} run data get storage #{src_storage} p_merge"
      #   # aout << "      > registry p_jsontext ++"
      #   # aout << "      execute store result storage #{src_storage} p_merge int 1 run \#{> registry p_jsontext get}"
      #   # aout << "      > registry p_jsontext reset"
      #   # aout << ""
      #   # aout << "      # keep iterating"
      #   # aout << "      /::up with storage #{src_storage}"
      #   # aout << "    ~>>"
      #   aout << "\t\t\t>>>"
      #   aout << "\t\t>>>"
      #   aout << "\t>>>"
      # })
    end
  end
end
