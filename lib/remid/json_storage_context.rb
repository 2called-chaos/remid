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

    def << str, inherit: true
      buf = str
      # buf = buf.call if buf.is_a?(Proc)
      buf = buf.to_s(inherit: inherit) if buf.is_a?(JsonHelper::PresentedMinecraftString)
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

    def concat! src_storage, name = "jsontext"
      #self.<<(%{{"nbt":"#{name}[]","storage":"#{src_storage}","interpret":true,"separator":""}})
      [].tap do |r|
        r << %{summon minecraft:text_display ~ ~ ~ {Tags:["#{$remid.function_namespace}", "#{$remid.scoreboard_namespace}.jsoneval"], text: '{"nbt":"#{name}[]","storage":"#{src_storage}","interpret":true,"separator":""}'}}
        r << %{data modify storage #{@storage} #{@name} append from entity @e[type=minecraft:text_display,limit=1,tag=#{$remid.scoreboard_namespace}.jsoneval] text}
        r << %{kill @e[type=minecraft:text_display,tag=#{$remid.scoreboard_namespace}.jsoneval]}
      end.join("\n")
    end

    def concat src_storage, name = "jsontext"
      unless $remid
        raise "cannot concat json storages without remid context"
      end
      unless Thread.current[:fparse_inst]
        raise "cannot concat json storages without function parser context"
      end

      Thread.current[:fparse_inst].resolve_fcall Thread.current[:fparse_inst].anonymous_function(inlined: true){|aout|
        aout << "data modify storage #{src_storage} p_merge set value 0"
        aout << "execute run <<~"
        aout << "\t$execute"
        aout << "\t\tif data storage #{src_storage} #{name}[$(p_merge)]"
        aout << "\t\trun <<~"
        aout << "\t\t\t$data modify storage #{@storage} #{@name} append from storage #{src_storage} #{name}[$(p_merge)]"
        aout << ""
        aout << "\t\t\t# increase pointer"
        aout << "\t\t\texecute store result score p_jsontext \#{> registry} run data get storage #{src_storage} p_merge"
        aout << "\t\t\t> registry p_jsontext ++"
        aout << "\t\t\texecute store result storage #{src_storage} p_merge int 1 run \#{> registry p_jsontext get}"
        aout << "\t\t\t> registry p_jsontext reset"
        aout << ""
        aout << "\t\t\t# keep iterating"
        aout << "\t\t\t/::up with storage #{src_storage}"
        aout << "\t\t~>>"
        aout << "~>> with storage #{src_storage}"
      }
    end
  end
end
