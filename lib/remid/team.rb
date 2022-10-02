module Remid
  class Team
    def initialize parent, key, **opts
      @parent = parent
      @key = key
      @opts = opts
      @opts[:friendly_fire] = @opts.delete(:ff) if @opts.key?(:ff)
      @opts.assert_valid_keys(:name, :color, :friendly_fire, :see_friendly_invisibles, :nametag, :death_messages, :collide, :prefix, :suffix)
    end

    def create cbuf: nil
      cbuf = $remid.buf(cbuf)
      cmd = "team add #{@key}"
      cmd << " \"#{@opts[:name]}\"" if @opts[:name]
      cbuf << cmd

      if @opts[:color]
        cbuf << "team modify #{@key} color #{@opts[:color]}"
      end

      if @opts.key?(:friendly_fire)
        cbuf << "team modify #{@key} friendlyFire #{@opts[:friendly_fire]}"
      end

      if @opts.key?(:see_friendly_invisibles)
        cbuf << "team modify #{@key} seeFriendlyInvisibles #{@opts[:friendly_fire]}"
      end

      if @opts.key?(:prefix)
        cbuf << "team modify #{@key} prefix #{@opts[:prefix]}"
      end

      if @opts.key?(:suffix)
        cbuf << "team modify #{@key} suffix #{@opts[:suffix]}"
      end

      if @opts.key?(:nametag)
        case @opts[:nametag]
        when false, :never then cbuf << "team modify #{@key} nametagVisibility never"
        when true, :always then cbuf << "team modify #{@key} nametagVisibility always"
        when :hide_for_other_teams then cbuf << "team modify #{@key} nametagVisibility hideForOtherTeams"
        when :hide_for_own_team then cbuf << "team modify #{@key} nametagVisibility hideForOwnTeam"
        else
          raise "unknown nametag option #{@opts[:nametag]} (may be true/:always false/:never :hide_for_other_teams or :hide_for_own_team"
        end
      end

      if @opts.key?(:death_messages)
        case @opts[:death_messages]
        when false, :never then cbuf << "team modify #{@key} deathMessageVisibility never"
        when true, :always then cbuf << "team modify #{@key} deathMessageVisibility always"
        when :hide_for_other_teams then cbuf << "team modify #{@key} deathMessageVisibility hideForOtherTeams"
        when :hide_for_own_team then cbuf << "team modify #{@key} deathMessageVisibility hideForOwnTeam"
        else
          raise "unknown death message option #{@opts[:death_messages]} (may be true/:always false/:never :hide_for_other_teams or :hide_for_own_team"
        end
      end

      if @opts.key?(:collide)
        case @opts[:collide]
        when false, :never then cbuf << "team modify #{@key} collisionRule never"
        when true, :always then cbuf << "team modify #{@key} collisionRule always"
        when :with_other_teams then cbuf << "team modify #{@key} collisionRule pushOtherTeams"
        when :with_own_team then cbuf << "team modify #{@key} collisionRule pushOwnTeam"
        else
          raise "unknown collide option #{@opts[:collide]} (may be true/:always false/:never :with_other_teams or :with_own_team"
        end
      end
    end

    def destroy cbuf: nil
      $remid.buf(cbuf) << "team remove #{@key}"
    end

    def to_s
      @key.to_s
    end
  end
end
