module Remid
  class Objective
    def initialize parent, key, type = "dummy", **opts
      @parent = parent
      @key = key
      @type = type
      @opts = opts
      @opts.assert_valid_keys(:name, :display, :render)
    end

    def create
      raise "no context" unless cbuf = Thread.current[:fparse_cbuf]
      cmd = "scoreboard objectives add #{@key} #{@type}"
      cmd << " \"#{@opts[:name]}\"" if @opts[:name]
      cbuf << cmd

      if @opts[:display]
        cbuf << "scoreboard objectives setdisplay #{@opts[:display]} #{@key}"
      end

      if @opts[:render]
        cbuf << "scoreboard objectives modify #{@key} rendertype #{@opts[:render]}"
      end
    end

    def destroy
      raise "no context" unless cbuf = Thread.current[:fparse_cbuf]
      cbuf << "scoreboard objectives remove #{@key}"
    end
  end
end
